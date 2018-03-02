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

package cloud::aws::elb::mode::performances;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

my $instance_mode;

sub prefix_metric_output {
    my ($self, %options) = @_;
    
    return "ELB '" . $options{instance_value}->{display} . "' " . $options{instance_value}->{stat} . " ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'metric', type => 1, cb_prefix_output => 'prefix_metric_output', message_multiple => "All performances metrics are ok", skipped_code => { -10 => 1 } },
    ];

    foreach my $statistic ('minimum', 'maximum', 'average', 'sum') {
        foreach my $metric ('RequestCount') {
            next if ($statistic =~ /minimum|maximum|average/); # Minimum, Maximum, and Average all return 1.
            my $entry = { label => lc($metric) . '-' . lc($statistic), set => {
                                key_values => [ { name => $metric . '_' . $statistic }, { name => 'display' }, { name => 'stat' } ],
                                output_template => $metric . ': %d requests',
                                perfdatas => [
                                    { label => lc($metric) . '_' . lc($statistic), value => $metric . '_' . $statistic . '_absolute', 
                                      template => '%d', unit => 'requests', label_extra_instance => 1, instance_use => 'display_absolute' },
                                ],
                            }
                        };
            push @{$self->{maps_counters}->{metric}}, $entry;
        }
        foreach my $metric ('Latency') {
            next if ($statistic =~ /minimum/); # Minimum is typically not useful
            my $entry = { label => lc($metric) . '-' . lc($statistic), set => {
                                key_values => [ { name => $metric . '_' . $statistic }, { name => 'display' }, { name => 'stat' } ],
                                output_template => $metric . ': %.2f sec',
                                perfdatas => [
                                    { label => lc($metric) . '_' . lc($statistic), value => $metric . '_' . $statistic . '_absolute', 
                                      template => '%.2f', unit => 's', label_extra_instance => 1, instance_use => 'display_absolute' },
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
                                    "region:s"         => { name => 'region' },
                                    "name:s@"	       => { name => 'name' },
                                    "filter-metric:s"  => { name => 'filter_metric' },
                                    "statistic:s@"     => { name => 'statistic' },
                                    "timeframe:s"      => { name => 'timeframe', default => 600 },
                                    "period:s"         => { name => 'period', default => 60 },
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

    if (!defined($self->{option_results}->{name}) || $self->{option_results}->{name} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --name option.");
        $self->{output}->option_exit();
    }

    foreach my $instance (@{$self->{option_results}->{name}}) {
        if ($instance ne '') {
            push @{$self->{aws_instance}}, $instance;
        }
    }

    $self->{aws_statistics} = ['Sum', 'Average'];
    if (defined($self->{option_results}->{statistic})) {
        $self->{aws_statistics} = [];
        foreach my $stat (@{$self->{option_results}->{statistic}}) {
            if ($stat ne '') {
                push @{$self->{aws_statistics}}, ucfirst(lc($stat));
            }
        }
    }

    foreach my $metric ('RequestCount', 'Latency') {
        next if (defined($self->{option_results}->{filter_metric}) && $self->{option_results}->{filter_metric} ne ''
            && $metric !~ /$self->{option_results}->{filter_metric}/);

        push @{$self->{aws_metrics}}, $metric;
    }

    $instance_mode = $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my %metric_results;
    foreach my $instance (@{$self->{aws_instance}}) {
        $metric_results{$instance} = $options{custom}->cloudwatch_get_metrics(
            region => $self->{option_results}->{region},
            namespace => 'AWS/ELB',
            dimensions => [ { Name => 'LoadBalancerName', Value => $instance } ],
            metrics => $self->{aws_metrics},
            statistics => $self->{aws_statistics},
            timeframe => $self->{option_results}->{timeframe},
            period => $self->{option_results}->{period},
        );
        
        foreach my $metric (@{$self->{aws_metrics}}) {
            foreach my $statistic (@{$self->{aws_statistics}}) {
                next if (!defined($metric_results{$instance}->{$metric}->{lc($statistic)}));

                $self->{metric}->{$instance . "_" . lc($statistic)}->{display} = $instance;
                $self->{metric}->{$instance . "_" . lc($statistic)}->{stat} = lc($statistic);
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

Check ELB performances.

Example: 
perl centreon_plugins.pl --plugin=cloud::aws::elb::plugin --custommode=paws --mode=performances --region='eu-west-1'
--name='elb-www-fr' --critical-requestcount-sum='10' --verbose

See 'https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/elb-metricscollected.html' for more informations.

=over 8

=item B<--region>

Set the region name (Required).

=item B<--name>

Set the instance name (Required) (Can be multiple).

=item B<--filter-metric>

Filter metrics (Can be: 'RequestCount', 'Latency') 
(Can be a regexp).

=item B<--statistic>

Set cloudwatch statistics (Default: 'sum', 'average')
(Can be: 'minimum', 'maximum', 'average', 'sum').

Most usefull statistics (RequestCount): 'sum'.
Most usefull statistics (Latency): 'average'.

=item B<--period>

Set period in seconds (Default: 60).

=item B<--timeframe>

Set timeframe in seconds (Default: 600).

=item B<--warning-$metric$-$statistic$>

Thresholds warning ($metric$ can be: 'requestcount', 'latency',
$statistic$ can be: 'minimum', 'maximum', 'average', 'sum').

=item B<--critical-$metric$-$statistic$>

Thresholds critical ($metric$ can be: 'requestcount', 'latency',
$statistic$ can be: 'minimum', 'maximum', 'average', 'sum').

=back

=cut
