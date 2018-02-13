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

package cloud::aws::ec2::mode::asgcpu;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub prefix_metric_output {
    my ($self, %options) = @_;
    
    return "ASG '" . $options{instance_value}->{display} . "' " . $options{instance_value}->{stat} . " ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'metric', type => 1, cb_prefix_output => 'prefix_metric_output', message_multiple => "All CPU metrics are ok", skipped_code => { -10 => 1 } },
    ];

    foreach my $statistic ('minimum', 'maximum', 'average', 'sum') {
        foreach my $metric ('CPUCreditBalance', 'CPUCreditUsage', 'CPUSurplusCreditBalance', 'CPUSurplusCreditsCharged') {
            my $entry = { label => lc($metric) . '-' . lc($statistic), set => {
                                key_values => [ { name => $metric . '_' . $statistic }, { name => 'display' }, { name => 'stat' } ],
                                output_template => $metric . ': %.3f',
                                perfdatas => [
                                    { label => lc($metric) . '_' . lc($statistic), value => $metric . '_' . $statistic . '_absolute', 
                                      template => '%.3f', label_extra_instance => 1, instance_use => 'display_absolute' },
                                ],
                            }
                        };
            push @{$self->{maps_counters}->{metric}}, $entry;
        }
        foreach my $metric ('CPUUtilization') {
            my $entry = { label => lc($metric) . '-' . lc($statistic), set => {
                                key_values => [ { name => $metric . '_' . $statistic }, { name => 'display' }, { name => 'stat' } ],
                                output_template => $metric . ': %.2f %%',
                                perfdatas => [
                                    { label => lc($metric) . '_' . lc($statistic), value => $metric . '_' . $statistic . '_absolute', 
                                      template => '%.2f', unit => '%', label_extra_instance => 1, instance_use => 'display_absolute' },
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
                                    "region:s"        => { name => 'region' },
                                    "asg-name:s@"	  => { name => 'asg_name' },
                                    "filter-metric:s" => { name => 'filter_metric' },
                                    "statistic:s@"    => { name => 'statistic' },
                                    "timeframe:s"     => { name => 'timeframe', default => 600 },
                                    "period:s"        => { name => 'period', default => 60 },
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

    if (!defined($self->{option_results}->{asg_name}) || $self->{option_results}->{asg_name} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --asg-name option.");
        $self->{output}->option_exit();
    }

    foreach my $asg_name (@{$self->{option_results}->{asg_name}}) {
        if ($asg_name ne '') {
            push @{$self->{aws_asg_name}}, $asg_name;
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

    foreach my $metric ('CPUCreditBalance', 'CPUCreditUsage', 'CPUSurplusCreditBalance', 'CPUSurplusCreditsCharged', 'CPUUtilization') {
        next if (defined($self->{option_results}->{filter_metric}) && $self->{option_results}->{filter_metric} ne ''
            && $metric !~ /$self->{option_results}->{filter_metric}/);

        push @{$self->{aws_metrics}}, $metric;
    }
}

sub manage_selection {
    my ($self, %options) = @_;

    my %metric_results;
    foreach my $asg_name (@{$self->{aws_asg_name}}) {
        $metric_results{$asg_name} = $options{custom}->cloudwatch_get_metrics(
            region => $self->{option_results}->{region},
            namespace => 'AWS/EC2',
            dimensions => [ { Name => 'AutoScalingGroupName', Value => $asg_name } ],
            metrics => $self->{aws_metrics},
            statistics => $self->{aws_statistics},
            timeframe => $self->{option_results}->{timeframe},
            period => $self->{option_results}->{period},
        );
    }
    
    foreach my $asg_name (keys %metric_results) {
        foreach my $metric (keys $metric_results{$asg_name}) {
            foreach my $stat ('minimum', 'maximum', 'average', 'sum') {
                next if (!defined($metric_results{$asg_name}->{$metric}->{$stat}));

                $self->{metric}->{$asg_name . "_" . $stat}->{display} = $asg_name;
                $self->{metric}->{$asg_name . "_" . $stat}->{stat} = $stat;
                $self->{metric}->{$asg_name . "_" . $stat}->{$metric . "_" . $stat} = $metric_results{$asg_name}->{$metric}->{$stat};
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

Check EC2 Auto Scaling Group CPU metrics.

Example: 
perl centreon_plugins.pl --plugin=cloud::aws::plugin --custommode=paws --mode=ec2-asg-cpu --region='eu-west-1' --asg-name='centreon-middleware' --filter-metric='Credit' --statistic='average' --critical-cpucreditusage-average='10' --verbose

=over 8

=item B<--region>

Set the region name (Required).

=item B<--asg-name>

Set the ASG name (Required) (Can be multiple).

=item B<--filter-metric>

Filter metrics (Can be: 'CPUCreditBalance', 'CPUCreditUsage', 
'CPUSurplusCreditBalance', 'CPUSurplusCreditsCharged', 'CPUUtilization') 
(Can be a regexp).

=item B<--statistic>

Set cloudwatch statistics (Default: 'average')
(Can be: 'minimum', 'maximum', 'average', 'sum').

=item B<--period>

Set period in seconds (Default: 60).

=item B<--timeframe>

Set timeframe in seconds (Default: 600).

=item B<--warning-$metric$-$statistic$>

Thresholds warning ($metric$ can be: 'cpucreditusage', 'cpucreditbalance', 
'cpusurpluscreditbalance', 'cpusurpluscreditscharged', 'cpuutilization', 
$statistic$ can be: 'minimum', 'maximum', 'average', 'sum').

=item B<--critical-$metric$-$statistic$>

Thresholds critical ($metric$ can be: 'cpucreditusage', 'cpucreditbalance', 
'cpusurpluscreditbalance', 'cpusurpluscreditscharged', 'cpuutilization', 
$statistic$ can be: 'minimum', 'maximum', 'average', 'sum').

=back

=cut
