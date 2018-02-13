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

sub prefix_elb_output {
    my ($self, %options) = @_;
    
    return "ELB '" . $options{instance_value}->{display} . "' " . ucfirst($options{instance_value}->{stat}) . ": ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'elb_perf', type => 1, cb_prefix_output => 'prefix_elb_output', message_multiple => "ELB Performances are OK", skipped_code => { -10 => 1 } },
    ];

    foreach my $statistic (('maximum', 'average', 'sum')) {
        foreach my $metric_name ('RequestCount', 'Latency') {
	    next if ($metric_name eq 'RequestCount' && $statistic ne 'sum' || $metric_name eq 'Latency' && $statistic !~ /average|maximum/);
            my $entry = { label => lc($metric_name) . '-' . lc($statistic), set => {
                                key_values => [ { name => $metric_name . '_' . $statistic }, { name => 'display' } ],
                                output_template => ($metric_name eq 'Latency') ? $metric_name . ' : %.2f sec' : $metric_name . ': %d requests',
                                perfdatas => [
                                    { label => lc($metric_name) . '_' . lc($statistic), value => $metric_name . '_' . $statistic . '_absolute',
                                      template => '%.2f', unit => ($metric_name eq 'Latency') ? 's' : 'request', label_extra_instance => 1, instance_use => 'display_absolute' },
                                ],
                            }
                        };
            push @{$self->{maps_counters}->{elb_perf}}, $entry;
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
                                "elb-name:s@"	  => { name => 'elb_name' },
                                "filter-metric:s" => { name => 'filter_metric' },
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
        $self->{output}->add_option_msg(short_msg => "Need to specify --elb-name option.");
        $self->{output}->option_exit();
    }

    foreach my $elb_name (@{$self->{option_results}->{elb_name}}) {
        if ($elb_name ne '') {
            push @{$self->{elb_name}}, $elb_name;
        }
    }

    foreach my $metric ('RequestCount', 'Latency') {
        next if (defined($self->{option_results}->{filter_metric}) && $self->{option_results}->{filter_metric} ne ''
            && $metric !~ /$self->{option_results}->{filter_metric}/);

        push @{$self->{aws_metrics}}, $metric;
    }


}

sub manage_selection {
    my ($self, %options) = @_;


    foreach my $elb_name (@{$self->{elb_name}}) {
        my $metric_results = $options{custom}->cloudwatch_get_metrics(
            region => $self->{option_results}->{region},
            namespace => 'AWS/ELB',
            dimensions => [ { Name => 'LoadBalancerName', Value => $elb_name } ],
            metrics => $self->{aws_metrics},
            statistics => ['Average', 'Maximum', 'Sum'],
            timeframe => $self->{option_results}->{timeframe},
            period => $self->{option_results}->{period},
        );
        foreach my $elb_stat (keys %{$metric_results}) {
	    foreach my $stat (('average', 'sum', 'maximum')) {
	        next if (!defined($metric_results->{$elb_stat}->{$stat}));
		$self->{elb_perf}->{$elb_name . '_' . $stat}->{display} = $elb_name;
	        $self->{elb_perf}->{$elb_name . '_' . $stat}->{$elb_stat . '_' . $stat} = $metric_results->{$elb_stat}->{$stat};
		$self->{elb_perf}->{$elb_name . '_' . $stat}->{stat} = $stat;
	    }
	}
    }

    if (scalar(keys %{$self->{elb_perf}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => '0 counter set, check your filter ? ');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Example: perl /tmp/work_sbo_aws/centreon-plugins/centreon_plugins.pl --plugin=cloud::aws::plugin --mode=elb-performances --aws-secret-key='secretkey' --aws-access-key='keyaws' --region='eu-west-1' --elb-name='elb-name' --verbose

=over 8

=item B<--region>

Set the region name (Required).


=item B<--elb-name>

Set the elb- name (Required, can be multiple).


=item B<--filter-metric>

Filter metrics (RequestCount, Latency)
(Can be a regexp).

=item B<--period>

Set period in seconds (Default: 60).

=item B<--timeframe>

Set timeframe in seconds (Default: 600).

=item B<--warning-latency-$aggregation>

Warning threshold for latency. $aggregation can be maximum to spot peak or average

=item B<--critical-latency-$aggregation>

Critical threshold for latency. $aggregation can be maximum to spot peak or average

=item B<--warning-requestcount-sum>

Warning threshold for request count.

=item B<--critical-requestcount-sum>

Critical threshold for request count. 

=back

=cut
