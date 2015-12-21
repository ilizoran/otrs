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

        # get helper object
        $Kernel::OM->ObjectParamAdd(
            'Kernel::System::UnitTest::Helper' => {
                RestoreSystemConfiguration => 1,
            },
        );
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # enable article filter
        $Kernel::OM->Get('Kernel::System::SysConfig')->ConfigItemUpdate(
            Valid => 1,
            Key   => 'Ticket::Frontend::TicketArticleFilter',
            Value => 1,
        );

        # get test data
        my @Tests = (
            {
                ArticleType => 'phone',
                SenderType  => 'customer',
                Subject     => 'First Test Article',
            },
            {
                ArticleType => 'email-external',
                SenderType  => 'system',
                Subject     => 'Second Test Article',
            },
            {
                ArticleType => 'note-internal',
                SenderType  => 'agent',
                Subject     => 'Third Test Article',
            },

        );

        # create and login test user
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users' ],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # get test user ID
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # create test ticket
        my $TicketID = $TicketObject->TicketCreate(
            Title      => 'Test Selenium Ticket',
            Queue      => 'Raw',
            Lock       => 'unlock',
            Priority   => '3 normal',
            State      => 'open',
            CustomerID => '12345',
            OwnerID    => $TestUserID,
            UserID     => $TestUserID,
        );
        $Self->True(
            $TicketID,
            "Ticket ID $TicketID - created",
        );

        # create test articles

        for(1..5){

            for my $Test ( @Tests ) {
                my $ArticleID = $TicketObject->ArticleCreate(
                    TicketID       => $TicketID,
                    ArticleType    => $Test->{ArticleType},
                    SenderType     => $Test->{SenderType},
                    Subject        => $Test->{Subject},
                    Body           => 'Selenium body article',
                    Charset        => 'ISO-8859-15',
                    MimeType       => 'text/plain',
                    HistoryType    => 'AddNote',
                    HistoryComment => 'Some free text!',
                    UserID         => $TestUserID,
                );
                $Self->True(
                    $ArticleID,
                    "Article $Test->{Subject} - created",
                );
            }
        }

    }

);

1;
