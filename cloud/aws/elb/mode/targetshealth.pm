#
# Copyright 2018 Centreon (http://www.centreon.com/)
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

package cloud::aws::elb::mode::targetshealth;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

my %map_type = (
    "loadbalancer"      => "LoadBalancerName",
    "availabilityzone"  => "AvailabilityZone",
);

sub prefix_metric_output {
    my ($self, %options) = @_;

    my $availability_zone = "";
    if (defined($options{instance_value}->{availability_zone})) {
        $availability_zone = "[$options{instance_value}->{availability_zone}] ";
    }
    
    return ucfirst($options{instance_value}->{type}) . " '" . $options{instance_value}->{display} . "' " . $availability_zone . $options{instance_value}->{stat} . " ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'metric', type => 1, cb_prefix_output => 'prefix_metric_output', message_multiple => "All health metrics are ok", skipped_code => { -10 => 1 } },
    ];

    foreach my $statistic ('minimum', 'maximum', 'average', 'sum') {
        foreach my $metric ('HealthyHostCount', 'UnHealthyHostCount') {
            my $entry = { label => lc($metric) . '-' . lc($statistic), set => {
                                key_values => [ { name => $metric . '_' . $statistic }, { name => 'display' }, { name => 'type' }, { name => 'stat' } ],
                                output_template => $metric . ': %d',
                                perfdatas => [
                                    { label => lc($metric) . '_' . lc($statistic), value => $metric . '_' . $statistic . '_absolute', 
                                      template => '%d', label_extra_instance => 1, instance_use => 'display_absolute' },
                                ],
                            }
                        };
            push @{$self->{maps_counters}->{metric}}, $entry;
        }
    }
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                {
                                    "region:s"              => { name => 'region' },
                                    "type:s"	            => { name => 'type' },
                                    "name:s@"	            => { name => 'name' },
                                    "availability-zone:s"   => { name => 'availability_zone' },
                                    "filter-metric:s"       => { name => 'filter_metric' },
                                    "statistic:s@"          => { name => 'statistic' },
                                    "timeframe:s"           => { name => 'timeframe', default => 600 },
                                    "period:s"              => { name => 'period', default => 60 },
                                });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    if (!defined($self->{option_results}->{region}) || $self->{option_results}->{region} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --region option.");
        $self->{output}->option_exit();
    }

    if (!defined($self->{option_results}->{type}) || $self->{option_results}->{type} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --type option.");
        $self->{output}->option_exit();
    }

    if ($self->{option_results}->{type} ne 'loadbalancer' && $self->{option_results}->{type} ne 'availabilityzone') {
        $self->{output}->output_add(severity => 'OK',
                                    short_msg => "Instance type '" . $self->{option_results}->{type} . "' is not handled for this mode");
        $self->{output}->display(force_ignore_perfdata => 1);
        $self->{output}->exit();
    }

    if ($self->{option_results}->{type} eq 'availabilityzone' && defined($self->{option_results}->{availability_zone})) {
        $self->{output}->add_option_msg(short_msg => "You can't specify --availability-zone option with availabilityzone instance's type");
        $self->{output}->option_exit();
    }

    if (!defined($self->{option_results}->{name}) || $self->{option_results}->{name} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --name option.");
        $self->{output}->option_exit();
    }

    foreach my $instance (@{$self->{option_results}->{name}}) {
        if ($instance ne '') {
            push @{$self->{aws_instance}}, $instance;
        }
    }

    $self->{aws_statistics} = ['Average'];
    if (defined($self->{option_results}->{statistic})) {
        $self->{aws_statistics} = [];
        foreach my $stat (@{$self->{option_results}->{statistic}}) {
            if ($stat ne '') {
                push @{$self->{aws_statistics}}, ucfirst(lc($stat));
            }
        }
    }

    foreach my $metric ('HealthyHostCount', 'UnHealthyHostCount') {
        next if (defined($self->{option_results}->{filter_metric}) && $self->{option_results}->{filter_metric} ne ''
            && $metric !~ /$self->{option_results}->{filter_metric}/);

        push @{$self->{aws_metrics}}, $metric;
    }

    if (defined($self->{option_results}->{availability_zone}) && $self->{option_results}->{availability_zone} ne '') {
        $self->{aws_availability_zone} = { Name => 'AvailabilityZone', Value => $self->{option_results}->{availability_zone} };
    }
}

sub manage_selection {
    my ($self, %options) = @_;

    my %metric_results;
    foreach my $instance (@{$self->{aws_instance}}) {
        push @{$self->{aws_dimensions}}, { Name => $map_type{$self->{option_results}->{type}}, Value => $instance };
        if (defined($self->{option_results}->{availability_zone}) && $self->{option_results}->{availability_zone} ne '') {
            push @{$self->{aws_dimensions}}, { Name => 'AvailabilityZone', Value => $self->{option_results}->{availability_zone} };
        }
        $metric_results{$instance} = $options{custom}->cloudwatch_get_metrics(
            region => $self->{option_results}->{region},
            namespace => 'AWS/ELB',
            dimensions => $self->{aws_dimensions},
            metrics => $self->{aws_metrics},
            statistics => $self->{aws_statistics},
            timeframe => $self->{option_results}->{timeframe},
            period => $self->{option_results}->{period},
        );
        
        foreach my $metric (@{$self->{aws_metrics}}) {
            foreach my $statistic (@{$self->{aws_statistics}}) {
                next if (!defined($metric_results{$instance}->{$metric}->{lc($statistic)}));

                $self->{metric}->{$instance . "_" . lc($statistic)}->{display} = $instance;
                $self->{metric}->{$instance . "_" . lc($statistic)}->{type} = $self->{option_results}->{type};
                $self->{metric}->{$instance . "_" . lc($statistic)}->{stat} = lc($statistic);
                $self->{metric}->{$instance . "_" . lc($statistic)}->{availability_zone} = $self->{option_results}->{availability_zone};
                $self->{metric}->{$instance . "_" . lc($statistic)}->{$metric . "_" . lc($statistic)} = $metric_results{$instance}->{$metric}->{lc($statistic)};
            }
        }
    }

    if (scalar(keys %{$self->{metric}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No metrics detected, check your filter ? ');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check ELB instances health.

Example: 
perl centreon_plugins.pl --plugin=cloud::aws::elb::plugin --custommode=paws --mode=instancehealth --region='eu-west-1'
--type='loadbalancer' --name='elb-www-fr' --critical-healthyhostcount-average='10' --verbose

See 'https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/elb-metricscollected.html' for more informations.

=over 8

=item B<--region>

Set the region name (Required).

=item B<--type>

Set the instance type (Required) (Can be: 'loadbalancer', 'availabilityzone').

=item B<--name>

Set the instance name (Required) (Can be multiple).

=item B<--availability-zone>

Add Availability Zone dimension (only with --type='loadbalancer').

=item B<--filter-metric>

Filter metrics (Can be: 'HealthyHostCount', 'UnHealthyHostCount') 
(Can be a regexp).

=item B<--statistic>

Set cloudwatch statistics (Default: 'average')
(Can be: 'minimum', 'maximum', 'average', 'sum').

Most usefull statistics: 'average', 'minimum', 'maximum'.

=item B<--period>

Set period in seconds (Default: 60).

=item B<--timeframe>

Set timeframe in seconds (Default: 600).

=item B<--warning-$metric$-$statistic$>

Thresholds warning ($metric$ can be: 'healthyhostcount', 'unhealthyhostcount',
$statistic$ can be: 'minimum', 'maximum', 'average', 'sum').

=item B<--critical-$metric$-$statistic$>

Thresholds critical ($metric$ can be: 'healthyhostcount', 'unhealthyhostcount',
$statistic$ can be: 'minimum', 'maximum', 'average', 'sum').

=back

=cut
