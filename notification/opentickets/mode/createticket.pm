#
# Copyright 2017 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package notification::opentickets::mode::createticket;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use centreon::plugins::misc;
use JSON;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                {
                                  "user:s"                   => { name => 'user' },
                                  "rule:s"                   => { name => 'rule' },
                                  "host-name:s"              => { name => 'host_name' },
                                  "host-status:s"            => { name => 'host_status' },
                                  "service-description:s"    => { name => 'service_description' },
                                  "service-status:s"         => { name => 'service_status' },
                                  "urgency:s"                => { name => 'urgency' },
                                  "impact:s"                 => { name => 'impact' },
                                  "mail"                     => { name => 'mail' },
                                  "mail-from:s"              => { name => 'mail_from' },
                                  "mail-to:s"                => { name => 'mail_to' },
                                  "mail-command:s"           => { name => 'mail_command', default => '/usr/bin/mail' },
                                });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (!defined($self->{option_results}->{rule}) || $self->{option_results}->{rule} eq '') {
        $self->{output}->add_option_msg(short_msg => "You need to specify --rule option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{user}) || $self->{option_results}->{user} eq '') {
        $self->{output}->add_option_msg(short_msg => "You need to specify --user option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{host_name}) || $self->{option_results}->{host_name} eq '') {
        $self->{output}->add_option_msg(short_msg => "You need to specify --host-name option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{host_status}) || $self->{option_results}->{host_status} eq '') {
        $self->{output}->add_option_msg(short_msg => "You need to specify --host-status option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{service_description}) || $self->{option_results}->{service_description} eq '') {
        $self->{output}->add_option_msg(short_msg => "You need to specify --service-description option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{service_status}) || $self->{option_results}->{service_status} eq '') {
        $self->{output}->add_option_msg(short_msg => "You need to specify --service-status option.");
        $self->{output}->option_exit();
    }

    $self->{user}
}

sub run {
    my ($self, %options) = @_;

    my %data = ( 
        user => $self->{option_results}->{user},
        rule => $self->{option_results}->{rule},
        hostname => $self->{option_results}->{host_name},
        host_status => $self->{option_results}->{host_status},
        service_description => $self->{option_results}->{service_description},
        service_status => $self->{option_results}->{service_status},
    );

    $data{urgency} = $self->{option_results}->{urgency} if defined($self->{option_results}->{urgency});
    $data{impact} = $self->{option_results}->{impact} if defined($self->{option_results}->{impact});

    my $encoded;
    eval {
        $encoded = encode_json(\%data);
    };
    if ($@) {
        $self->{output}->add_option_msg(short_msg => "Cannot encode json request");
        $self->{output}->option_exit();
    }
    
    my $result = $options{custom}->post_call(path => '/index.php?object=centreon_openticket_polyconseil&action=createTicket', data => $encoded);
    
    if (defined($self->{option_results}->{mail}) && defined($self->{option_results}->{mail_from}) && $self->{option_results}->{mail_from} ne '' 
        && defined($self->{option_results}->{mail_to}) && $self->{option_results}->{mail_to} ne '' && defined($result->{code}) && $result->{code} == 2) {
        my $subject = "[Centreon] Ouverture manuelle du ticket pour " . $self->{option_results}->{host_name} . "/" . $self->{option_results}->{service_description} . "/" . $self->{option_results}->{service_status};
        my $message = "Ouverture manuelle du ticket nécessaire pour le service suivant :\n\n";
        $message .= "Host: " . $self->{option_results}->{host_name} . "\n";
        $message .= "Service: " . $self->{option_results}->{service_description}. "\n";
        $message .= "Status: " . $self->{option_results}->{service_status}. "\n";
        my $command = sprintf("/usr/bin/printf '%s' | %s -s '%s' -r %s %s", $message,
            $self->{option_results}->{mail_command},
            $subject,
            $self->{option_results}->{mail_from},
            $self->{option_results}->{mail_to});
        centreon::plugins::misc::backtick(command => $command);
    }

    $self->{output}->output_add(severity => 'OK',
                                short_msg => sprintf("Return message: %s", $result->{message}));
    $self->{output}->display();
    $self->{output}->exit();
}
        
1;

__END__

=head1 MODE

Create tickets.

=over 8

=item B<--user>

Centreon user allowed to execute external commands (Mandatory)

=item B<--rule>

Centreon Open Tickets rule to be applied (Mandatory)

=item B<--host-name>

Name of the host, usually $HOSTNAME$ macro (Mandatory)

=item B<--host-status>

Status of the host, usually $HOSTSTATE$ macro (Mandatory)

=item B<--service-description>

Name of the service, usually $SERVICEDESC$ macro (Mandatory)

=item B<--service-status>

Status of the service, usually $SERVICESTATE$ macro (Mandatory)

=item B<--urgency>

Urgency level of the ticket, can be $_SERVICECRITICALITY_ID$ macro (Optionnal)

=item B<--impact>

Impact level of the ticket (Optionnal)

=item B<--mail>

Send a mail if the alert require a call (Optionnal)

=item B<--mail-from>

Sender of the mail (Mandatory if option --mail)

=item B<--mail-to>

Recipient of the mail (Mandatory if option --mail)

=item B<--mail-command>

Client used to send mail (Default : '/usr/bin/mail')

=back

=cut
