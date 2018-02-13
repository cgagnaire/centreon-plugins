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

package cloud::aws::elb::mode::instancehealth;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub prefix_elb_output {
    my ($self, %options) = @_;

    return "ELB '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'count_host', type => 1, cb_prefix_output => 'prefix_elb_output', skipped_code => { -10 => 1 } },
    ];

    foreach my $statistic (('average', 'maximum')) {
        foreach my $metric_name ('HealthyHostCount', 'UnHealthyHostCount') {
            my $entry = { label => lc($metric_name) . '-' . lc($statistic), set => {
                                key_values => [ { name => $metric_name . '_' . $statistic }, { name => 'display' } ],
                                output_template => $metric_name . ' ' . $statistic . ': %d instances',
                                perfdatas => [
                                    { label => lc($metric_name) . '_' . lc($statistic), value => $metric_name . '_' . $statistic . '_absolute',
                                      template => '%.2f', unit => 'instance', label_extra_instance => 1, instance_use => 'display_absolute' },
                                ],
                            }
                        };
            push @{$self->{maps_counters}->{count_host}}, $entry;
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
                                "elb-name:s"      => { name => 'elb_name' },
                                "statistic:s@"    => { name => 'statistic' },
				"extra-dimension:s%" => { name => 'extra_dimension' },
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

    if (!defined($self->{option_results}->{elb_name}) || $self->{option_results}->{elb_name} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --elb_name option.");
        $self->{output}->option_exit();
    }

    my $append = '';
    $self->{aws_dimensions} = [ { Name => 'LoadBalancerName', Value => $self->{option_results}->{elb_name} } ];
    if (defined($self->{option_results}->{extra_dimension})) {
        foreach (keys %{$self->{option_results}->{extra_dimension}}) {
            push @{$self->{aws_dimensions}}, { Name => $_, Value => $self->{option_results}->{extra_dimension}->{$_} };
            $self->{dimension_name} .= $append . $_ . '.' . $self->{option_results}->{extra_dimension}->{$_};
            $append = '-';
        }
    }


}

sub manage_selection {
    my ($self, %options) = @_;

    my $metric_results = $options{custom}->cloudwatch_get_metrics(
        region => $self->{option_results}->{region},
        namespace => 'AWS/ELB',
        dimensions => $self->{aws_dimensions},
        metrics => ['HealthyHostCount', 'UnHealthyHostCount'],
        statistics => ['Average', 'Maximum'],
        timeframe => $self->{option_results}->{timeframe},
        period => $self->{option_results}->{period},
    );


    use Data::Dumper; print Dumper($metric_results);
    foreach my $host_stat (keys %{$metric_results}) {
        foreach my $stat (('average', 'maximum')) {
            next if (!defined($metric_results->{$host_stat}->{$stat}));
            $self->{count_host}->{$self->{option_results}->{elb_name}}->{display} = $self->{option_results}->{elb_name};
            $self->{count_host}->{$self->{option_results}->{elb_name}}->{$host_stat . '_' . $stat} = $metric_results->{$host_stat}->{$stat};
        }
    }

    if (scalar(keys %{$self->{count_host}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => '0 counter set, check your filter ? ');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check instance health behind an AWS ELB

Example:
perl centreon_plugins.pl --plugin=cloud::aws::plugin --mode=elb-instance-health --custommode='awscli' --region='eu-west-1' --aws-secret-key='secretkey' --aws-access-key='keyaws' --region='eu-west-1' --elb-name='elb-name' --verbose

=over 8

=item B<--region>

Set the region name (Required).

=item B<--elb-name>

ELB Name (Mandatory)

=item B<--period>

Set period in seconds (Default: 60).

=item B<--timeframe>

Set timeframe in seconds (Default: 600).

=item B<--warning-$metric-$aggregation>

Warning thresholds. ($metric can be: 'healthyhostcount' or 'unhealthyhostcount')
($aggregation can be: 'average', 'maximum')

=item B<--critical-$metric-$aggregation>

Critical thresholds. ($metric can be: 'healthyhostcount' or 'unhealthyhostcount')
($aggregation can be: 'average', 'maximum')

=back

=cut
