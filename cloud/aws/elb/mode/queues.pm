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

package cloud::aws::elb::mode::queues;

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
        { name => 'elb_queue', type => 1, cb_prefix_output => 'prefix_elb_output', message_multiple => "Hosts behind the ELB are OK", skipped_code => { -10 => 1 } },
    ];

    foreach my $statistic (('minimum', 'maximum', 'average', 'sum')) {
        foreach my $metric_name ('SpilloverCount', 'SurgeQueueLength') {
            my $entry = { label => lc($metric_name), set => {
                                key_values => [ { name => $metric_name }, { name => 'display' } ],
                                output_template => $metric_name . ' ' . $statistic . ': %d',
                                perfdatas => [
                                    { label => lc($metric_name), value => $metric_name . '_absolute',
                                      template => '%d', label_extra_instance => 1, instance_use => 'display_absolute' },
                                ],
                            }
                        };
            push @{$self->{maps_counters}->{elb_queue}}, $entry;
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
                                "elb-name:s"	  => { name => 'elb_name' },
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

}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{aws_metrics} = ['SpilloverCount', 'SurgeQueueLength'];

    my $metric_results = $options{custom}->cloudwatch_get_metrics(
        region => $self->{option_results}->{region},
        namespace => 'AWS/ELB',
        dimensions => [ { Name => 'LoadBalancerName', Value => $self->{option_results}->{elb_name} } ],
        metrics => $self->{aws_metrics},
        statistics => ['Average', 'Maximum', 'Minimum', 'Sum'],
        timeframe => $self->{option_results}->{timeframe},
        period => $self->{option_results}->{period},
    );
    

    foreach my $host_stat (keys %{$metric_results}) {
        foreach my $stat (('average', 'sum', 'maximum', 'minimum')) {
            next if ($host_stat eq 'SpilloverCount' && $stat ne 'Sum');
            $metric_results->{$host_stat}->{$stat} = (defined($metric_results->{$host_stat}->{$stat})) ? $metric_results->{$host_stat}->{$stat} : 0;
            $self->{elb_queue}->{$self->{option_results}->{elb_name}}->{display} = $self->{option_results}->{elb_name} . '_' . $stat;
            $self->{elb_queue}->{$self->{option_results}->{elb_name}}->{$host_stat} = $metric_results->{$host_stat}->{$stat};	}
    }
}

1;

__END__

=head1 MODE

perl centreon_plugins.pl --plugin=cloud::aws::plugin --mode=elb-queues --custommode='paws' --aws-secret-key='feafEAAFAefea' --aws-access-key='feafaefeavcrg' --region='eu-west-1' --elb-name='elb-name' --verbose

=over 8

=item B<--region>

Set the region name (Required).

=item B<--filter-metric>

Filter metrics 
(Can be a regexp).

=item B<--period>

Set period in seconds (Default: 60).

=item B<--timeframe>

Set timeframe in seconds (Default: 600).

=item B<--warning-$metric$-$statistic$>

=item B<--critical-$metric$-$statistic$>

=back

=cut
