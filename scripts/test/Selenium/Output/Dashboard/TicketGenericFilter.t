# --
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        # get needed objects
        $Kernel::OM->ObjectParamAdd(
            'Kernel::System::UnitTest::Helper' => {
                RestoreSystemConfiguration => 1,
            },
        );
        my $Helper       = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # create test user
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users' ],
        ) || die "Did not get test user";

        # get test user ID
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        # create test ticket
        my $CustomerUserID = $Helper->GetRandomID() . '@localhost.com';
        my $TicketNumber   = $TicketObject->TicketCreateNumber();
        my $TicketID       = $TicketObject->TicketCreate(
            TN           => $TicketNumber,
            Title        => 'Selenium Test Ticket',
            Queue        => 'Raw',
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'new',
            CustomerID   => '12345',
            CustomerUser => $CustomerUserID,
            OwnerID      => $TestUserID,
            UserID       => $TestUserID,
        );
        $Self->True(
            $TicketID,
            "Ticket ID $TicketID - created"
        );

        # login test user
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # get script alias
        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        # navigate to SysConfig screen
        $Selenium->get("${ScriptAlias}index.pl?Action=AdminSysConfig");

        # search for 0120-TicketNew SysConfig
        $Selenium->find_element("//input[\@id='SysConfigSearch'][\@title='Search']")->send_keys('0120-TicketNew');
        $Selenium->find_element("//button[\@value='Search'][\@type='submit']")->click();

        # click on found SysConfig
        $Selenium->find_element("//a[contains(\@href, \'Action=AdminSysConfig;Subaction=Edit' )]")->click();

        # find CustomerUserID for TicketNew dashboard SysConfig and set it as default column
        $Selenium->find_element(
            "//input[\@name='DashboardBackend###0120-TicketNew##SubHash##DefaultColumnsKey[]'][\@title='CustomerUserID']"
        )->send_keys( "\N{U+E004}", '2' );

        # submit SysConfig
        $Selenium->find_element("//button[\@class='CallForAction'][\@value='Update']")->click();

        # navigate to dashboard screen
        $Selenium->get("${ScriptAlias}index.pl?");

        # click on column setting filter for CustomerUserID in TicketNew generic dashboard overview
        $Selenium->find_element("//a[contains(\@title, \'CustomerUserID\' )]")->click();

        # select test CustomerUserID as filter for TicketNew generic dashboard overview
        my $ParentElement = $Selenium->find_element( "div.ColumnSettingsBox", 'css' );
        $Selenium->find_child_element( $ParentElement, "./input" )->send_keys($CustomerUserID);
        $Selenium->execute_script(
            "\$('#ColumnFilterCustomerUserID0120-TicketNew').val('$CustomerUserID').trigger('redraw.InputField').trigger('change');"
        );

        # verify we found test ticket by filtering with customer that is not in DB, see bug #10117
        $Self->True(
            index( $Selenium->get_page_source(), $TicketNumber ) > -1,
            "Test ticket ID $TicketID with TN $TicketNumber - found on screen after filtering with unknown customer",
        );

        # delete test ticket
        my $Success = $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );
        $Self->True(
            $Success,
            "Ticket ID $TicketID - deleted"
        );

        # make sure cache is correct
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
            Type => 'Ticket',
        );

    }
);

1;
