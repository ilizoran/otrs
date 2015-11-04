# --
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AutoResponse;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::SystemAddress',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::AutoResponse - auto response lib

=head1 SYNOPSIS

All auto response functions. E. g. to add auto response or other functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AutoResponseObject = $Kernel::OM->Get('Kernel::System::AutoReponse');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item AutoResponseAdd()

add auto response with attributes

    $AutoResponseObject->AutoResponseAdd(
        Name        => 'Some::AutoResponse',
        ValidID     => 1,
        Subject     => 'Some Subject..',
        Response    => 'Auto Response Test....',
        ContentType => 'text/plain',
        AddressID   => 1,
        TypeID      => 1,
        UserID      => 123,
    );

=cut

sub AutoResponseAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Name ValidID Response ContentType AddressID TypeID UserID Subject)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check if a auto-response with this name already exits
    return if !$Self->_NameExistsCheck( Name => $Param{Name} );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # insert into database
    return if !$DBObject->Do(
        SQL => '
            INSERT INTO auto_response
                (name, valid_id, comments, text0, text1, type_id, system_address_id,
                content_type, create_time, create_by, change_time, change_by)
            VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{Comment}, \$Param{Response},
            \$Param{Subject},     \$Param{TypeID}, \$Param{AddressID},
            \$Param{ContentType}, \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get id
    return if !$DBObject->Prepare(
        SQL => '
            SELECT id
            FROM auto_response
            WHERE name = ?
                AND type_id = ?
                AND system_address_id = ?
                AND content_type = ?
                AND create_by = ?',
        Bind => [
            \$Param{Name}, \$Param{TypeID}, \$Param{AddressID},
            \$Param{ContentType}, \$Param{UserID},
        ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return $ID;
}

=item AutoResponseGet()

get auto response with attributes

    my %Data = $AutoResponseObject->AutoResponseGet(
        ID => 123,
    );

=cut

sub AutoResponseGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ID!',
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # select
    return if !$DBObject->Prepare(
        SQL => '
            SELECT id, name, valid_id, comments, text0, text1, type_id, system_address_id,
                content_type, create_time, create_by, change_time, change_by
            FROM auto_response WHERE id = ?',
        Bind  => [ \$Param{ID} ],
        Limit => 1,
    );

    my %Data;
    while ( my @Data = $DBObject->FetchrowArray() ) {

        %Data = (
            ID          => $Data[0],
            Name        => $Data[1],
            ValidID     => $Data[2],
            Comment     => $Data[3],
            Response    => $Data[4],
            Subject     => $Data[5],
            TypeID      => $Data[6],
            AddressID   => $Data[7],
            ContentType => $Data[8] || 'text/plain',
            CreateTime  => $Data[9],
            CreateBy    => $Data[10],
            ChangeTime  => $Data[11],
            ChangeBy    => $Data[12],
        );
    }

    my %Types = $Self->AutoResponseTypeList();
    $Data{Type} = $Types{ $Data{TypeID} };

    return %Data;
}

=item AutoResponseUpdate()

update auto response with attributes

    $AutoResponseObject->AutoResponseUpdate(
        ID          => 123,
        Name        => 'Some::AutoResponse',
        ValidID     => 1,
        Subject     => 'Some Subject..',
        Response    => 'Auto Response Test....',
        ContentType => 'text/plain',
        AddressID   => 1,
        TypeID      => 1,
        UserID      => 123,
    );

=cut

sub AutoResponseUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ID Name ValidID Response AddressID ContentType UserID Subject)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check if a auto-response with this name already exits
    return if !$Self->_NameExistsCheck(
        Name => $Param{Name},
        ID   => $Param{ID},
    );

    # update the database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => '
            UPDATE auto_response
            SET name = ?, text0 = ?, comments = ?, text1 = ?, type_id = ?,
                system_address_id = ?, content_type = ?, valid_id = ?,
                change_time = current_timestamp, change_by = ?
            WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{Response}, \$Param{Comment}, \$Param{Subject}, \$Param{TypeID},
            \$Param{AddressID}, \$Param{ContentType}, \$Param{ValidID},
            \$Param{UserID}, \$Param{ID},
        ],
    );

    return 1;
}

=item AutoResponseGetByTypeQueueID()

get a hash with data from Auto Response and it's corresponding System Address

    my %QueueAddressData = $AutoResponseObject->AutoResponseGetByTypeQueueID(
        QueueID => 3,
        Type    => 'auto reply/new ticket',
    );

Return example:

    %QueueAddressData(
        #Auto Response Data
        'Text'            => 'Your OTRS TeamOTRS! answered by a human asap.',
        'Subject'         => 'New ticket has been created! (RE: <OTRS_CUSTOMER_SUBJECT[24]>)',
        'ContentType'     => 'text/plain',
        'SystemAddressID' => '1',

        #System Address Data
        'ID'              => '1',
        'Name'            => 'otrs@localhost',
        'Address'         => 'otrs@localhost',  #Compatibility with OTRS 2.1
        'Realname'        => 'OTRS System',
        'Comment'         => 'Standard Address.',
        'ValidID'         => '1',
        'QueueID'         => '1',
        'CreateTime'      => '2010-03-16 21:24:03',
        'ChangeTime'      => '2010-03-16 21:24:03',
    );

=cut

sub AutoResponseGetByTypeQueueID {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(QueueID Type)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # SQL query
    return if !$DBObject->Prepare(
        SQL => "
            SELECT ar.text0, ar.text1, ar.content_type, ar.system_address_id
            FROM auto_response_type art, auto_response ar, queue_auto_response qar
            WHERE ar.valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet())} )
                AND qar.queue_id = ?
                AND art.id = ar.type_id
                AND qar.auto_response_id = ar.id
                AND art.name = ?",
        Bind => [
            \$Param{QueueID},
            \$Param{Type},
        ],
        Limit => 1,
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{Text}            = $Row[0];
        $Data{Subject}         = $Row[1];
        $Data{ContentType}     = $Row[2] || 'text/plain';
        $Data{SystemAddressID} = $Row[3];
    }

    # return if no auto response is configured
    return if !%Data;

    # get sender attributes
    my %Address = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressGet(
        ID => $Data{SystemAddressID},
    );

    # COMPAT: 2.1
    $Data{Address} = $Address{Name};

    # return both, sender attributes and auto response attributes
    return ( %Address, %Data );
}

=item AutoResponseList()

get a list of the Auto Responses

    my %AutoResponse = $AutoResponseObject->AutoResponseList(
        Valid => 0,     # (optional) default 0
    );

Return example:

    %AutoResponse = (
        '1' => 'default reply (after new ticket has been created) ( 1 )',
        '2' => 'default reject (after follow up and rejected of a closed ticket) ( 2 )',
        '3' => 'default follow up (after a ticket follow up has been added) ( 3 )',
    );

=cut

sub AutoResponseList {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # create sql
    my $SQL = 'SELECT id, name FROM auto_response ';
    if ( $Param{Valid} ) {
        $SQL
            .= "WHERE valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet())} )";
    }

    # select
    return if !$DBObject->Prepare( SQL => $SQL );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = "$Row[1] ( $Row[0] )";
    }

    return %Data;
}

=item AutoResponseTypeList()

get a list of the Auto Response Types

    my %AutoResponseType = $AutoResponseObject->AutoResponseTypeList(
        Valid => 1,     # (optional) default 1
    );

Return example:

    %AutoResponseType = (
        '1' => 'auto reply',
        '2' => 'auto reject',
        '3' => 'auto follow up',
        '4' => 'auto reply/new ticket',
        '5' => 'auto remove',
    );

=cut

sub AutoResponseTypeList {
    my ( $Self, %Param ) = @_;

    my $Valid = $Param{Valid} || 1;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # create sql
    my $SQL = 'SELECT id, name FROM auto_response_type ';
    if ($Valid) {
        $SQL
            .= "WHERE valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet())} )";
    }

    # select
    return if !$DBObject->Prepare( SQL => $SQL );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    return %Data;
}

=item AutoResponseListByType()

get a list of the Auto Response by Type

    my %AutoResponseListByType = $AutoResponseObject->AutoResponseListByType(
        TypeID  => 1,
        Valid   => 1,     # (optional) default 1
    );

Return example:

    %AutoResponseListByType = (
        '1' => 'default follow up (after a ticket follow up has been added)',
        '2' => 'auto reject',
        '3' => 'auto follow up',
    );

=cut

sub AutoResponseListByType {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TypeID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need TypeID!",
        );
        return;
    }

    my $Valid = $Param{Valid} || 1;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # create sql
    my $SQL = "SELECT ar.id, ar.name FROM auto_response ar, auto_response_type art
                WHERE art.id = ? AND ar.type_id = art.id";
    if ($Valid) {
        $SQL
            .= " AND ar.valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet())} )";
    }

    # select
    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => [ \$Param{TypeID} ],
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    return %Data;
}

=item AutoResponseIDForQueueByType()

get a list of the Auto Response for Queue by Type

    my $AutoResponseID = $AutoResponseObject->AutoResponseIDForQueueByType(
        TypeID    => 1,
        QueueID   => 2,
    );

Return example:

    $AutoResponseID = 1

=cut

sub AutoResponseIDForQueueByType {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TypeID QueueID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # create sql
    my $SQL = "SELECT ar.id FROM auto_response ar, auto_response_type art, queue_auto_response qar "
        . "WHERE art.id = ? AND ar.type_id = art.id AND qar.queue_id = ? "
        . "AND qar.auto_response_id = ar.id";

    # select
    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => [ \$Param{TypeID}, \$Param{QueueID} ],
        Limit => 1,
    );

    my $AutoResponseID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $AutoResponseID = $Row[0];
    }

    return $AutoResponseID;
}

=item GetAutoResponseData()

get a list of the Auto Response for Queue by Type

    my @GetAutoResponseData = $AutoResponseObject->GetAutoResponseData();

Return example:

    @GetAutoResponseData =
    (
          {
            'ID' => '1',
            'Type' => 'auto reply',
            'Name' => 'default reply (after new ticket has been created)'
          }
          {
            'ID' => '2',
            'Type' => 'auto reject',
            'Name' => 'default reject (after follow-up and rejected of a closed ticket)'
          },
       # ...
    );

=cut

sub GetAutoResponseData {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # create sql
    my $SQL = "SELECT ar.name, art.name, ar.id FROM "
        . " auto_response ar, auto_response_type art, valid "
        . " WHERE ar.type_id = art.id "
        . " AND ar.valid_id = valid.id "
        . " AND ar.valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet())} )"
        . " ORDER BY ar.name ASC"
        ;

    # select
    return if !$DBObject->Prepare( SQL => $SQL );

    my @ResponseData;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        my %AutoResponseData;
        $AutoResponseData{Name} = $Row[0];
        $AutoResponseData{Type} = $Row[1];
        $AutoResponseData{ID}   = $Row[2];
        push( @ResponseData, \%AutoResponseData );
    }

    return @ResponseData;
}

=item AutoResponseQueue()

assigns a list of auto-responses to a queue

    my @AutoResponseIDs = (1,2,3);

    $AutoResponseObject->AutoResponseQueue (
        QueueID         => 1,
        AutoResponseIDs => \@AutoResponseIDs,
        UserID          => 1,
    );

=cut

sub AutoResponseQueue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(QueueID AutoResponseIDs UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # store queue:auto response relations
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM queue_auto_response WHERE queue_id = ?',
        Bind => [ \$Param{QueueID} ],
    );

    NEWID:
    for my $NewID ( @{ $Param{AutoResponseIDs} } ) {

        next NEWID if !$NewID;

        $DBObject->Do(
            SQL => '
                INSERT INTO queue_auto_response (queue_id, auto_response_id,
                    create_time, create_by, change_time, change_by)
                VALUES
                    (?, ?, current_timestamp, ?, current_timestamp, ?)',
            Bind => [
                \$Param{QueueID},
                \$NewID,
                \$Param{UserID},
                \$Param{UserID},
            ],
        );
    }

    return 1;
}

=begin Internal:

=item _NameExistsCheck()

return if another auto-response with this name already exits

    $AutoResponseObject->_NameExistsCheck(
        Name => 'Some::AutoResponse',
        ID   => 1, # optional
    );

=cut

sub _NameExistsCheck {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM auto_response WHERE name = ?',
        Bind => [ \$Param{Name} ],
    );

    # fetch the result
    my $Flag;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( !$Param{ID} || $Param{ID} ne $Row[0] ) {
            $Flag = 1;
        }
    }

    if ($Flag) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "An Auto-Response with name '$Param{Name}' already exists!",
        );
        return;
    }

    return 1;
}

=end Internal:

=cut

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
