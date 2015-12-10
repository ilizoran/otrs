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

# get needed objects
my $ConfigObject           = $Kernel::OM->Get('Kernel::Config');
my $DBObject               = $Kernel::OM->Get('Kernel::System::DB');
my $StandardTemplateObject = $Kernel::OM->Get('Kernel::System::StandardTemplate');
my $Selenium               = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => ['admin'],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $UserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        my $ScriptAlias = $ConfigObject->Get('ScriptAlias');

        my $QueueRandomID = "queue" . $Helper->GetRandomID();

        # add test queue
        my $QueueID = $Kernel::OM->Get('Kernel::System::Queue')->QueueAdd(
            Name            => $QueueRandomID,
            ValidID         => 1,
            GroupID         => 1,
            SystemAddressID => 1,
            SalutationID    => 1,
            SignatureID     => 1,
            UserID          => $UserID,
            Comment         => 'Selenium Test Queue',
        );

        $Self->True(
            $QueueID,
            "Test Queue is created - $QueueID"
        );

        my @Templates;

        # create test template
        for ( 1 .. 2 ) {
            my $TemplateRandomID = "StandardTemplate" . $Helper->GetRandomID();
            my $TemplateID       = $StandardTemplateObject->StandardTemplateAdd(
                Name         => $TemplateRandomID,
                Template     => 'Thank you for your email.',
                ContentType  => 'text/plain; charset=utf-8',
                TemplateType => 'Answer',
                ValidID      => 1,
                UserID       => $UserID,
            );

            $Self->True(
                $TemplateID,
                "Test StandardTemplate is created - $TemplateID"
            );

            my %Template = (
                TemplateID => $TemplateID,
                Name       => $TemplateRandomID,
            );
            push @Templates, \%Template;
        }

        # check overview AdminQueueTemplates screen
        $Selenium->get("${ScriptAlias}index.pl?Action=AdminQueueTemplates");

        for my $ID (
            qw(Templates Queues FilterTemplates FilterQueues)
            )
        {
            my $Element = $Selenium->find_element( "#$ID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # check for test template and test queue on screen
        $Self->True(
            index( $Selenium->get_page_source(), $Templates[0]->{Name} ) > -1,
            "$Templates[0]->{Name} found on screen"
        );
        $Self->True(
            index( $Selenium->get_page_source(), $QueueRandomID ) > -1,
            "$QueueRandomID found on screen"
        );

        # test search filters
        $Selenium->find_element( "#FilterTemplates", 'css' )->send_keys( $Templates[0]->{Name} );
        $Selenium->find_element( "#FilterQueues",    'css' )->send_keys($QueueRandomID);
        sleep 1;

        $Self->True(
            $Selenium->find_element("//a[contains(\@href, \'Subaction=Template;ID=$Templates[0]->{TemplateID}' )]")
                ->is_displayed(),
            "$Templates[0]->{Name} found on screen with filter on",
        );

        $Self->True(
            $Selenium->find_element("//a[contains(\@href, \'Subaction=Queue;ID=$QueueID' )]")->is_displayed(),
            "$QueueRandomID found on screen with filter on",
        );

        # change test Queue relation for test Template
        $Selenium->find_element("//a[contains(\@href, \'Subaction=Template;ID=$Templates[0]->{TemplateID}' )]")
            ->click();
        $Selenium->find_element("//input[\@value='$QueueID'][\@type='checkbox']")->click();
        $Selenium->find_element("//button[\@value='Submit'][\@type='submit']")->click();

        # change test Template relation for test Queue
        $Selenium->find_element("//a[contains(\@href, \'Subaction=Queue;ID=$QueueID' )]")->click();
        $Selenium->find_element("//input[\@value='$Templates[1]->{TemplateID}'][\@type='checkbox']")->click();

        # test checked and unchecked values while filter is used for Template
        # test filter with "WrongFilterTemplate" to uncheck all values
        $Selenium->find_element( "#Filter", 'css' )->clear();
        $Selenium->find_element( "#Filter", 'css' )->send_keys("WrongFilterTemplate");

        # test is no data matches
        $Self->True(
            $Selenium->find_element( ".FilterMessage.Hidden>td", 'css' )->is_displayed(),
            "'No data matches' is displayed'"
        );

        # check template filter with existing Template
        $Selenium->find_element( "#Filter", 'css' )->clear();
        $Selenium->find_element( "#Filter", 'css' )->send_keys( $Templates[1]->{Name} );
        sleep 1;

        # uncheck the second test standard template
        $Selenium->find_element("//input[\@value='$Templates[1]->{TemplateID}'][\@type='checkbox']")->click();

        # test checked and unchecked values after using filter
        $Selenium->find_element( "#Filter", 'css' )->clear();
        $Selenium->find_element( "#Filter", 'css' )->send_keys("StandardTemplate");
        sleep 1;

        $Self->Is(
            $Selenium->find_element("//input[\@value='$Templates[0]->{TemplateID}'][\@type='checkbox']")->is_selected(),
            1,
            "$QueueRandomID is in a relation with $Templates[0]->{Name}",
        );
        $Self->Is(
            $Selenium->find_element("//input[\@value='$Templates[1]->{TemplateID}'][\@type='checkbox']")->is_selected(),
            0,
            "$QueueRandomID is not in a relation with $Templates[1]->{Name}",
        );

        # since there are no tickets that rely on our test QueueTemplate,
        # we can remove test template and  test queue from the DB

        my $Success;
        if ($QueueID) {
            $Success = $DBObject->Do(
                SQL => "DELETE FROM queue_standard_template WHERE queue_id = $QueueID",
            );
            $Self->True(
                $Success,
                "Deleted standard_template_queue relation"
            );

            $Success = $DBObject->Do(
                SQL => "DELETE FROM queue WHERE id = $QueueID",
            );
            $Self->True(
                $Success,
                "Deleted queue- $QueueRandomID",
            );
        }

        for my $Template (@Templates) {
            $Success = $StandardTemplateObject->StandardTemplateDelete(
                ID => $Template->{TemplateID},
            );

            $Self->True(
                $Success,
                "Deleted StandardTemplate - $Template->{TemplateID}",
            );
        }

        # make sure the cache is correct.
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
            Type => "Queue",
        );

    }

);

1;
