# --
# PID.t - PID tests
# Copyright (C) 2001-2005 Martin Edenhofer <martin+code@otrs.org>
# --
# $Id: PID.t,v 1.1 2005-12-20 22:53:43 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use Kernel::System::PID;

$Self->{PIDObject} = Kernel::System::PID->new(%{$Self});

my $PIDCreate = $Self->{PIDObject}->PIDCreate(
    Name => 'Test',
);

$Self->True(
    $PIDCreate,
    'PIDCreate()',
);

my $PIDCreate2 = $Self->{PIDObject}->PIDCreate(
    Name => 'Test',
);

$Self->True(
    (!$PIDCreate2),
    'PIDCreate2()',
);

my $PIDGet = $Self->{PIDObject}->PIDGet(
    Name => 'Test',
);

$Self->True(
    $PIDGet,
    'PIDGet()',
);

my $PIDDelete = $Self->{PIDObject}->PIDDelete(
    Name => 'Test',
);

$Self->True(
    $PIDDelete,
    'PIDDelete()',
);

1;
