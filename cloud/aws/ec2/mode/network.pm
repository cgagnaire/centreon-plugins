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

package cloud::aws::ec2::mode::network;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

my %map_type = (
    "instance" => "InstanceId",
    "asg"      => "AutoScalingGroupName",
);

my $instance_mode;

sub prefix_metric_output {
    my ($self, %options) = @_;
    
    return ucfirst($options{instance_value}->{type}) . " '" . $options{instance_value}->{display} . "' " . $options{instance_value}->{stat} . " ";
}

sub custom_metric_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{value} = $options{new_datas}->{$self->{instance} . '_' . $options{extra_options}->{metric} . '_' . $options{extra_options}->{stat}};
    $self->{result_values}->{value_per_sec} = $self->{result_values}->{value} / $instance_mode->{option_results}->{timeframe};
    $self->{result_values}->{stat} = $options{extra_options}->{stat};
    $self->{result_values}->{metric} = $options{extra_options}->{metric};
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    return 0;
}

sub custom_metric_threshold {
    my ($self, %options) = @_;

    my $exit = $self->{perfdata}->threshold_check(value => defined($instance_mode->{option_results}->{per_sec}) ?  $self->{result_values}->{value_per_sec} : $self->{result_values}->{value},
                                                  threshold => [ { label => 'critical-' . lc($self->{result_values}->{metric}) . "-" . lc($self->{result_values}->{stat}), exit_litteral => 'critical' },
                                                                 { label => 'warning-' . lc($self->{result_values}->{metric}) . "-" . lc($self->{result_values}->{stat}), exit_litteral => 'warning' } ]);
    return $exit;
}

sub custom_traffic_perfdata {
    my ($self, %options) = @_;

    my $extra_label = '';
    $extra_label = '_' . lc($self->{result_values}->{display}) if (!defined($options{extra_instance}) || $options{extra_instance} != 0);

    $self->{output}->perfdata_add(label => lc($self->{result_values}->{metric}) . "_" . lc($self->{result_values}->{stat}) . $extra_label,
				                  unit => defined($instance_mode->{option_results}->{per_sec}) ? 'B/s' : 'B',
                                  value => sprintf("%.2f", defined($instance_mode->{option_results}->{per_sec}) ? $self->{result_values}->{value_per_sec} : $self->{result_values}->{value}),
                                  warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . lc($self->{result_values}->{metric}) . "-" . lc($self->{result_values}->{stat})),
                                  critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . lc($self->{result_values}->{metric}) . "-" . lc($self->{result_values}->{stat})),
                                 );
}

sub custom_traffic_output {
    my ($self, %options) = @_;
    my $msg = "";

    if (defined($instance_mode->{option_results}->{per_sec})) {
	    my ($value, $unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{value_per_sec});
        $msg = $self->{result_values}->{metric}  . ": " . $value . $unit . "/s"; 
    } else {
        my ($value, $unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{value});
        $msg = $self->{result_values}->{metric}  . ": " . $value . $unit;
    }
    return $msg;
}

sub custom_packets_perfdata {
    my ($self, %options) = @_;

    my $extra_label = '';
    $extra_label = '_' . lc($self->{result_values}->{display}) if (!defined($options{extra_instance}) || $options{extra_instance} != 0);

    $self->{output}->perfdata_add(label => lc($self->{result_values}->{metric}) . "_" . lc($self->{result_values}->{stat}) . $extra_label,
                                  unit => defined($instance_mode->{option_results}->{per_sec}) ? 'packets/s' : 'packets',
                                  value => sprintf("%.2f", defined($instance_mode->{option_results}->{per_sec}) ? $self->{result_values}->{value_per_sec} : $self->{result_values}->{value}),
                                  warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . lc($self->{result_values}->{metric}) . "-" . lc($self->{result_values}->{stat})),
                                  critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . lc($self->{result_values}->{metric}) . "-" . lc($self->{result_values}->{stat})),
                                 );
}

sub custom_packets_output {
    my ($self, %options) = @_;

    my $msg ="";

    if (defined($instance_mode->{option_results}->{per_sec})) {
        $msg = sprintf("%s: %.2f packets/s", $self->{result_values}->{metric}, $self->{result_values}->{value_per_sec});
    } else {
        $msg = sprintf("%s: %.2f packets", $self->{result_values}->{metric}, $self->{result_values}->{value});
    }
 
    return $msg;
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'metric', type => 1, cb_prefix_output => 'prefix_metric_output', message_multiple => "All network metrics are ok", skipped_code => { -10 => 1 } },
    ];

    foreach my $statistic ('minimum', 'maximum', 'average', 'sum') {
        foreach my $metric ('NetworkIn', 'NetworkOut') {
            my $entry = { label => lc($metric) . '-' . lc($statistic), set => {
                                key_values => [ { name => $metric . '_' . $statistic }, { name => 'display' }, { name => 'stat' } ],
                                closure_custom_calc => $self->can('custom_metric_calc'),
                                closure_custom_calc_extra_options => { metric => $metric, stat => $statistic },
                                closure_custom_output => $self->can('custom_traffic_output'),
                                closure_custom_perfdata => $self->can('custom_traffic_perfdata'),
                                closure_custom_threshold_check => $self->can('custom_metric_threshold'),
                            }
                        };
            push @{$self->{maps_counters}->{metric}}, $entry;
        }
        foreach my $metric ('NetworkPacketsIn', 'NetworkPacketsOut') {
            my $entry = { label => lc($metric) . '-' . lc($statistic), set => {
                                key_values => [ { name => $metric . '_' . $statistic }, { name => 'display' }, { name => 'stat' } ],
                                closure_custom_calc => $self->can('custom_metric_calc'),
                                closure_custom_calc_extra_options => { metric => $metric, stat => $statistic },
                                closure_custom_output => $self->can('custom_packets_output'),
                                closure_custom_perfdata => $self->can('custom_packets_perfdata'),
                                closure_custom_threshold_check => $self->can('custom_metric_threshold'),
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
                                    "type:s"           => { name => 'type' },
                                    "name:s@"          => { name => 'name' },
                                    "filter-metric:s"  => { name => 'filter_metric' },
                                    "statistic:s@"     => { name => 'statistic' },
                                    "timeframe:s"      => { name => 'timeframe', default => 600 },
                                    "period:s"         => { name => 'period', default => 60 },
                                    "per-sec"	       => { name => 'per_sec' },
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

    if ($self->{option_results}->{type} ne 'asg' && $self->{option_results}->{type} ne 'instance') {
        $self->{output}->output_add(severity => 'OK',
                                    short_msg => "Instance type '" . $self->{option_results}->{type} . "' is not handled for this mode");
        $self->{output}->display(force_ignore_perfdata => 1);
        $self->{output}->exit();
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

    foreach my $metric ('NetworkIn', 'NetworkOut', 'NetworkPacketsIn', 'NetworkPacketsOut') {
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
            namespace => 'AWS/EC2',
            dimensions => [ { Name => $map_type{$self->{option_results}->{type}}, Value => $instance } ],
            metrics => $self->{aws_metrics},
            statistics => $self->{aws_statistics},
            timeframe => $self->{option_results}->{timeframe},
            period => $self->{option_results}->{period},
        );
        
        foreach my $metric (keys $metric_results{$instance}) {
            foreach my $stat ('minimum', 'maximum', 'average', 'sum') {
                next if (!defined($metric_results{$instance}->{$metric}->{$stat}));

                $self->{metric}->{$instance . "_" . $stat}->{display} = $instance;
                $self->{metric}->{$instance . "_" . $stat}->{type} = $self->{option_results}->{type};
                $self->{metric}->{$instance . "_" . $stat}->{stat} = $stat;
                $self->{metric}->{$instance . "_" . $stat}->{$metric . "_" . $stat} = $metric_results{$instance}->{$metric}->{$stat};
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

Check EC2 instances network metrics.

Example: 
perl centreon_plugins.pl --plugin=cloud::aws::plugin --custommode=paws --mode=ec2-network --region='eu-west-1'
--type='asg' --name='centreon-middleware' --filter-metric='Packets' --statistic='sum'
--critical-networkpacketsout-sum='10' --verbose

=over 8

=item B<--region>

Set the region name (Required).

=item B<--type>

Set the instance type (Required) (Can be: 'asg', 'instance').

=item B<--name>

Set the instance name (Required) (Can be multiple).

=item B<--filter-metric>

Filter metrics (Can be: 'NetworkIn', 'NetworkOut', 
'NetworkPacketsIn', 'NetworkPacketsOut') 
(Can be a regexp).

=item B<--statistic>

Set cloudwatch statistics (Default: 'average')
(Can be: 'minimum', 'maximum', 'average', 'sum').

=item B<--period>

Set period in seconds (Default: 60).

=item B<--timeframe>

Set timeframe in seconds (Default: 600).

=item B<--warning-$metric$-$statistic$>

Thresholds warning ($metric$ can be: 'networkin', 'networkout', 
'networkpacketsin', 'networkpacketsout', 
$statistic$ can be: 'minimum', 'maximum', 'average', 'sum').

=item B<--critical-$metric$-$statistic$>

Thresholds critical ($metric$ can be: 'networkin', 'networkout', 
'networkpacketsin', 'networkpacketsout', 
$statistic$ can be: 'minimum', 'maximum', 'average', 'sum').

=item B<--per-sec>

Change the data to be unit/sec.

=back

=cut
