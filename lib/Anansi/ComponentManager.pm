package Anansi::ComponentManager;


=head1 NAME

Anansi::ComponentManager - A base module definition for related process management.

=head1 SYNOPSIS

    package Anansi::ComponentManagerExample;

    use base qw(Anansi::ComponentManager);

    sub doSomethingElse {
        my ($self, $channel, %parameters) = @_;
    }

    Anansi::ComponentManager::addChannel(
        'Anansi::ComponentManagerExample',
        'SOME_MANAGER_CHANNEL' => Anansi::ComponentManagerExample->doSomethingElse
    );

    1;

    package Anansi::ComponentManagerExample::ComponentExample;

    use base qw(Anansi::Component);

    sub validate {
        return 1;
    }

    sub doSomething {
        my ($self, $channel, %parameters) = @_;
    }

    Anansi::Component::addChannel(
        'Anansi::ComponentManagerExample::ComponentExample',
        'VALIDATE_AS_APPROPRIATE' => Anansi::ComponentManagerExample::ComponentExample->validate
    );
    Anansi::Component::addChannel(
        'Anansi::ComponentManagerExample::ComponentExample',
        'SOME_COMPONENT_CHANNEL' => Anansi::ComponentManagerExample::ComponentExample->doSomething
    );

    1;

=head1 DESCRIPTION

This is a base module definition for the management of modules that deal with
related functionality.  This management module provides the mechanism to handle
multiple related functionality modules at the same time, loading and creating an
object of the most appropriate module to handle each situation.  In order to
simplify the recognition of related L<Anansi::Component> modules, each component
is required to have the same base namespace as it's manager.  See
L<Anansi::Singleton> for inherited methods.  Makes use of L<base>, and
L<Anansi::Actor>.

=cut


our $VERSION = '0.04';

use base qw(Anansi::Singleton);

use Anansi::Actor;


my %CHANNELS;
my %COMPONENTS;
my %IDENTIFICATIONS;


=head1 METHODS

=cut


=head2 addChannel

    if(1 == Anansi::ComponentManager->addChannel(
        someChannel => 'Some::subroutine',
        anotherChannel => Some::subroutine,
        yetAnotherChannel => $AN_OBJECT->someSubroutine,
        etcChannel => sub {
            my $self = shift(@_);
        }
    ));

    if(1 == $OBJECT->addChannel(
        someChannel => 'Some::subroutine',
        anotherChannel => Some::subroutine,
        yetAnotherChannel => $AN_OBJECT->someSubroutine,
        etcChannel => sub {
            my $self = shift(@_);
        }
    ));

=over 4

=item self I<(Blessed Hash B<or> String, Required)>

Either an object or a string of this namespace.

=item parameters I<(Hash, Required)>

Named parameters where the key is the name of the channel and the value is
either a namespace string or code reference to an existing subroutine or an
anonymous subroutine definition.

=back

Defines the responding subroutine for the named component manager channels.

=cut


sub addChannel {
    my ($self, %parameters) = @_;
    my $package = $self;
    $package = ref($self) if(ref($self) !~ /^$/);
    return 0 if(0 == scalar(keys(%parameters)));
    foreach my $key (keys(%parameters)) {
        if(ref($key) !~ /^$/) {
            return 0;
        } elsif(ref($parameters{$key}) =~ /^CODE$/i) {
        } elsif(ref($parameters{$key}) !~ /^$/) {
            return 0;
        } elsif($parameters{$key} =~ /^[a-zA-Z]+[a-zA-Z0-9_]*(::[a-zA-Z]+[a-zA-Z0-9_]*)*$/) {
            if(exists(&{$parameters{$key}})) {
            } elsif(exists(&{$package.'::'.$parameters{$key}})) {
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }
    $CHANNELS{$package} = {} if(!defined($CHANNELS{$package}));
    foreach my $key (keys(%parameters)) {
        if(ref($parameters{$key}) =~ /^CODE$/i) {
            ${$CHANNELS{$package}}{$key} = sub {
                my ($self, $channel, @PARAMETERS) = @_;
                return &{$parameters{$key}}($self, $channel, (@PARAMETERS));
            };
        } elsif($parameters{$key} =~ /^[a-zA-Z]+[a-zA-Z0-9_]*(::[a-zA-Z]+[a-zA-Z0-9_]*)*$/) {
            if(exists(&{$parameters{$key}})) {
                ${$CHANNELS{$package}}{$key} = sub {
                    my ($self, $channel, @PARAMETERS) = @_;
                    return &{\&{$parameters{$key}}}($self, $channel, (@PARAMETERS));
                };
            } else {
                ${$CHANNELS{$package}}{$key} = sub {
                    my ($self, $channel, @PARAMETERS) = @_;
                    return &{\&{$package.'::'.$parameters{$key}}}($self, $channel, (@PARAMETERS));
                };
            }
        }
    }
    return 1;
}


=head2 addComponent

    my $identification = Anansi::ComponentManager->addComponent(
        undef,
        someParameter => 'some value'
    );
    if(defined($identification));

    my $identification = $OBJECT->addComponent(
        undef,
        someParameter => 'some value'
    );
    if(defined($identification));

    my $identification = Anansi::ComponentManager->addComponent(
        'some identifier',
        someParameter => 'some value'
    );
    if(defined($identification));

    my $identification = $OBJECT->addComponent(
        'some identifier',
        someParameter => 'some value'
    );
    if(defined($identification));

=over 4

=item self I<(Blessed Hash B<or> String, Required)>

An object or string of this namespace.

=item identification I<(String, Required)>

The name to associate with the component.

=item parameters I<(Scalar B<or> Array, Optional)>

The list of parameters to pass to the I<VALIDATE_AS_APPROPRIATE> channel of
every component module found on the system.

=back

Creates a new component object and stores the object for indirect interaction by
the implementer of the component manager.  A unique identifier for the object
may either be supplied or automatically generated and is returned as a means of
referencing the object.

Note: The process of selecting the component to use requires each component to
validate it's own appropriateness.  Therefore this process makes use of a
VALIDATE_AS_APPROPRIATE component channel which is expected to return either a
B<1> I<(one)> or a B<0> I<(zero)> representing B<appropriate> or
B<inappropriate>.  If this component channel does not exist it is assumed that
the component is not designed to be implemented in this way.

=cut


sub addComponent {
    my ($self, $identification, @parameters) = @_;
    my $package = $self;
    $package = ref($self) if(ref($self) !~ /^$/);
    $identification = $self->componentIdentification() if(!defined($identification));
    if(defined($COMPONENTS{$package})) {
        return $identification if(defined(${$COMPONENTS{$package}}{$identification}));
    }
    my $components = $self->components();
    return if(ref($components) !~ /^ARRAY$/i);
    my $OBJECT;
    foreach my $component (@{$components}) {
        my $valid = &{\&{'Anansi::Component::channel'}}($component, 'VALIDATE_AS_APPROPRIATE', (@parameters));
        next if(!defined($valid));
        if($valid) {
            $OBJECT = Anansi::Actor->new(PACKAGE => $component, (@parameters));
            last;
        }
    }
    return if(!defined($OBJECT));
    $COMPONENTS{$package} = {} if(!defined($COMPONENTS{$package}));
    ${$COMPONENTS{$package}}{$identification} = $OBJECT;
    $self->uses(
        'COMPONENT_'.$identification => $OBJECT,
    );
    $IDENTIFICATIONS{$identification} = 1;
    return $identification;
}


=head2 channel

    Anansi::ComponentManager->channel('Anansi::ComponentManager::Example');

    $OBJECT->channel();

    Anansi::ComponentManager->channel(
        'Anansi::ComponentManager::Example',
        'someChannel',
        someParameter => 'something'
    );

    $OBJECT->channel('someChannel', someParameter => 'something');

=over 4

=item self I<(Blessed Hash B<or> String, Required)>

An object or string of this namespace.

=item channel I<(String, Optional)>

The name that is associated with the component's channel.

=item parameters I<(Scalar B<or> Array, Optional)>

The list of parameters to pass to the component's channel.

=back

Either returns an array of the available channels or passes the supplied
parameters to the named channel.  Returns B<undef> on B<error>.

=cut


sub channel {
    my $self = shift(@_);
    $self = shift(@_) if('Anansi::ComponentManager' eq $self);
    my $package = $self;
    $package = ref($self) if(ref($self) !~ /^$/);
    if(0 == scalar(@_)) {
        return [] if(!defined($CHANNELS{$package}));
        return [( keys(%{$CHANNELS{$package}}) )];
    }
    my ($channel, @parameters) = @_;
    return if(ref($channel) !~ /^$/);
    return if(!defined($CHANNELS{$package}));
    return if(!defined(${$CHANNELS{$package}}{$channel}));
    return &{${$CHANNELS{$package}}{$channel}}($self, $channel, (@parameters));
}


=head2 component

    my $returned;
    my $channels = Anansi::ComponentManager->component($component);
    if(defined($channels)) {
        foreach my $channel (@{$channels}) {
            next if('SOME_CHANNEL' ne $channel);
            $returned = Anansi::ComponentManager->component(
                $component,
                $channel,
                anotherParameter => 'another value'
            );
        }
    }

    my @returned;
    $OBJECT->addComponent(undef, someParameter => 'some value');
    my $components = $OBJECT->component();
    if(defined($components)) {
        foreach my $component (@{$components}) {
            my $channels = $OBJECT->component($component);
            if(defined($channels)) {
                foreach my $channel (@{$channels}) {
                    next if('SOME_CHANNEL' ne $channel);
                    push(@returned, $OBJECT->component(
                        $component,
                        $channel,
                        anotherParameter => 'another value'
                    ));
                }
            }
        }
    }

=over 4

=item self I<(Blessed Hash B<or> String, Required)>

An object or string of this namespace.

=item identification I<(String, Optional)>

The name associated with the component.

=item channel I<(String, Optional)>

The name that is associated with the component's channel.

=item parameters I<(Scalar B<or> Array, Optional)>

The list of parameters to pass to the component's channel.

=back

Either returns an array of all of the available components or an array of all
of the channels available through an identified component or interacts with an
identified component using one of it's channels.  Returns an B<undef> on
B<failure>.

=cut


sub component {
    my $self = shift(@_);
    my $package = $self;
    $package = ref($self) if(ref($self) !~ /^$/);
    return if(!defined($COMPONENTS{$package}));
    return [( keys(%{$COMPONENTS{$package}}) )] if(0 == scalar(@_));
    my $identification = shift(@_);
    return if(!defined($identification));
    return if(!defined(${$COMPONENTS{$package}}{$identification}));
    my $OBJECT = ${$COMPONENTS{$package}}{$identification};
    return $OBJECT->channel() if(0 == scalar(@_));
    my ($channel, @parameters) = @_;
    return $OBJECT->channel($channel, (@parameters));
}


=head2 componentIdentification

    my $identification = Anansi::ComponentManager->componentIdentification();

    my $identification = $OBJECT->componentIdentification();

=over 4

=item self I<(Blessed Hash, Required)>

An object of this namespace.

=back

Generates a unique identification string.  Intended to be replaced by an
extending module.  Indirectly called.

=cut


sub componentIdentification {
    my ($self) = @_;
    my ($second, $minute, $hour, $day, $month, $year) = localtime(time);
    my $random;
    my $identification;
    do {
        $random = int(rand(1000000));
        $identification = sprintf("%4d%02d%02d%02d%02d%02d%06d", $year + 1900, $month, $day, $hour, $minute, $second, $random);
    } while(defined($IDENTIFICATIONS{$identification}));
    return $identification;
}


=head2 components

    my $components = Anansi::ComponentManager->components();
    if(ref($components) =~ /^ARRAY$/i) {
        foreach my $component (@{$components}) {
        }
    }

    my $components = Anansi::ComponentManager::components('Some::Namespace');
    if(ref($components) =~ /^ARRAY$/i) {
        foreach my $component (@{$components}) {
        }
    }

    my $components = $OBJECT->components();
    if(ref($components) =~ /^ARRAY$/i) {
        foreach my $component (@{$components}) {
        }
    }

=over 4

=item self I<(Blessed Hash B<or> String, Required)>

An object or string of this namespace.

=back

Either returns an array of all of the available components or an array
containing the current component manager's components.

=cut


sub components {
    my $self = shift(@_);
    my $package = $self;
    $package = ref($package) if(ref($package) !~ /^$/);
    my %modules = Anansi::Actor->modules();
    my @components;
    if('Anansi::ComponentManager' eq $package) {
        foreach my $module (keys(%modules)) {
            next if('Anansi::Component' eq $module);
            require $modules{$module};
            next if(!eval { $module->isa('Anansi::Component') });
            push(@components, $module);
        }
        return [(@components)];
    }
    my @namespaces = split(/::/, $package);
    my $namespace = join('::', @namespaces).'::';
    foreach my $module (keys(%modules)) {
        next if($module !~ /^${namespace}[^:]+$/);
        require $modules{$module};
        next if(!eval { $module->isa('Anansi::Component') });
        push(@components, $module);
    }
    return [(@components)];
}


=head2 finalise

Inherited from L<Anansi::Singleton>.

=cut


=head2 initialise

Inherited from L<Anansi::Singleton>.

=cut


=head2 new

Inherited from L<Anansi::Singleton>.

=cut


=head2 removeChannel

    if(1 == Anansi::ComponentManager::removeChannel(
        'Anansi::ComponentManagerExample',
        'someChannel',
        'anotherChannel',
        'yetAnotherChannel',
        'etcChannel'
    ));

    if(1 == $OBJECT->removeChannel(
        'someChannel',
        'anotherChannel',
        'yetAnotherChannel',
        'etcChannel'
    ));

=over 4

=item self I<(Blessed Hash B<or> String, Required)>

An object or string of this namespace.

=item parameters I<(Scalar B<or> Array, Required)>

The channels to remove.

=back

Undefines the responding subroutine for the named component manager's channels.

=cut


sub removeChannel {
    my ($self, @parameters) = @_;
    my $package = $self;
    $package = ref($self) if(ref($self) !~ /^$/);
    return 0 if(0 == scalar(@parameters));
    return 0 if(!defined($CHANNELS{$package}));
    foreach my $key (@parameters) {
        return 0 if(!defined(${$CHANNELS{$package}}{$key}));
    }
    foreach my $key (@parameters) {
        delete ${$CHANNELS{$package}}{$key};
    }
    return 1;
}


=head2 removeComponent

    if(1 == Anansi::ComponentManager::removeComponent(
        'Anansi::ComponentManagerExample',
        'someComponent',
        'anotherComponent',
        'yetAnotherComponent',
        'etcComponent'
    ));

    if(1 == $OBJECT->removeComponent(
        'someComponent',
        'anotherComponent',
        'yetAnotherComponent',
        'etcComponent'
    ));

=over 4

=item self I<(Blessed Hash B<or> String, Required)>

An object or string of this namespace.

=item parameters I<(Array, Required)>

A string or array of strings containing the name of a component.

=back

Releases a named component instance for garbage collection.  Returns a B<1>
I<(one)> or a B<0> I<(zero)> representing B<success> or B<failure>.

=cut


sub removeComponent {
    my ($self, @parameters) = @_;
    my $package = $self;
    $package = ref($self) if(ref($self) !~ /^$/);
    return 0 if(0 == scalar(@parameters));
    return 0 if(!defined($COMPONENTS{$package}));
    foreach my $key (@parameters) {
        return 0 if(!defined(${$COMPONENTS{$package}}{$key}));
    }
    foreach my $key (@parameters) {
        delete ${$COMPONENTS{$package}}{$key};
        $self->used('COMPONENT_'.$key);
    }
    return 1;
}


=head1 NOTES

This module is designed to make it simple, easy and quite fast to code your
design in perl.  If for any reason you feel that it doesn't achieve these goals
then please let me know.  I am here to help.  All constructive criticisms are
also welcomed.

=cut


=head1 AUTHOR

Kevin Treleaven <kevin I<AT> treleaven I<DOT> net>

=cut


1;
