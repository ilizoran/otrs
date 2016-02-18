# --
# Kernel/Modules/AgentHelloWorld.pm - frontend module
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentHelloWorld;

use strict;
use warnings;

use Kernel::System::HelloWorld;
use Kernel::Modules::AdminType;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless ($Self, $Type);

    # # check needed objects
    # for (qw(ParamObject DBObject TicketObject LayoutObject LogObject QueueObject ConfigObject EncodeObject MainObject)) {
    #     if ( !$Self->{$_} ) {
    #         $Self->{LayoutObject}->FatalError( Message => "Got no $_!" );
    #     }
    # }

    # # create needed objects
    # $Self->{HelloWorldObject} = Kernel::System::HelloWorld->new(%Param);

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Data = Kernel::System::HelloWorld->GetHelloWorldText('test stranica');
    my $Users = Kernel::Modules::AdminType->_Overview();

    # build output
    my $Output = $LayoutObject->Header(Title => "HelloWorld");
    $Output   .= $LayoutObject->NavigationBar();


    $Output   .= $LayoutObject->Output(
        Data => { Test => $Data },
        TemplateFile => 'AgentHelloWorld',
    );
    $Output   .= $LayoutObject->Output(
        Data => { Users => $Users },
        TemplateFile => 'AdminType',
    );
    $Output   .= $LayoutObject->Footer();
    return $Output;
}

1;