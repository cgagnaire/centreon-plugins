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

package cloud::aws::elb::mode::httpcodes;

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
        { name => 'http_codes', type => 1, cb_prefix_output => 'prefix_elb_output', message_multiple => "Backend HTTP codes are ok", skipped_code => { -10 => 1 } },
    ];

    foreach my $metric_name ('BackendConnectionErrors', 'HTTPCode-Backend-2XX', 'HTTPCode-Backend-3XX', 'HTTPCode-Backend-4XX', 'HTTPCode-Backend-5XX', 'HTTPCode-ELB-4XX', 'HTTPCode-ELB-5XX') {
        my $entry = { label => lc($metric_name), set => {
                            key_values => [ { name => $metric_name }, { name => 'display' } ],
                            output_template => $metric_name . ': %d ',
                            perfdatas => [
                                { label => lc($metric_name), value => $metric_name . '_absolute',
                                  template => '%d', label_extra_instance => 1, instance_use => 'display_absolute' },
                            ],
                        }
                    };
        push @{$self->{maps_counters}->{http_codes}}, $entry;
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

    if (!defined($self->{option_results}->{elb_name}) || $self->{option_results}->{elb_name} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --elb-name option.");
        $self->{output}->option_exit();
    }

    foreach my $elb_name (@{$self->{option_results}->{elb_name}}) {
        if ($elb_name ne '') {
            push @{$self->{elb_name}}, $elb_name;
        }
    }

    foreach my $metric ('HTTPCode_Backend_2XX', 'HTTPCode_Backend_3XX', 'HTTPCode_Backend_4XX', 'HTTPCode_Backend_5XX', 'HTTPCode_ELB_4XX', 'HTTPCode_ELB_5XX', 'BackendConnectionErrors') {
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
            statistics => ['Sum'],
            timeframe => $self->{option_results}->{timeframe},
            period => $self->{option_results}->{period},
        );
	foreach my $elb_stat (keys %{$metric_results}) {
	    my $value = $metric_results->{$elb_stat}->{points};
	    $elb_stat =~ s/_/-/g;
	    $self->{http_codes}->{$elb_name}->{display} = $elb_name;
	    $self->{http_codes}->{$elb_name}->{$elb_stat} = $value;
        }
    }

    if (scalar(keys %{$self->{http_codes}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => '0 counter set, check your filter ? ');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check EC2 Auto Scaling Group CPU metrics.

perl /tmp/work_sbo_aws/centreon-plugins/centreon_plugins.pl --plugin=cloud::aws::plugin --mode=elb-http-codes --custommode='paws' --aws-secret-key='XXXx' --aws-access-key='XXX' --region='eu-west-1' --elb-name='elb-centreon-frontend' --warning-httpcode_backend_2xx --verbose

=over 8

=item B<--region>

Set the region name (Required).

=item B<--elb-name>

Set the elb name (Required). Can be multiple

=item B<--filter-metric>

Filter metrics (Can be: 'HTTPCode_Backend_2XX', 'HTTPCode_Backend_3XX', 'HTTPCode_Backend_4XX',
'HTTPCode_Backend_5XX', 'HTTPCode_ELB_4XX', 'HTTPCode_ELB_5XX', 'BackendConnectionErrors')
(Can be a regexp).

=item B<--period>

Set period in seconds (Default: 60).

=item B<--timeframe>

Set timeframe in seconds (Default: 600).

=item B<--warning-$metric$>

Thresholds warning
($metric$ can be: 'httpcode-backend-2xx', 'httpcode-backend-4xx', 
'httpcode-backend-5xx', 'httpcode-backend-3xx', 'backendconnectionerrors')

=item B<--critical-$metric$>

Thresholds critical
($metric$ can be: 'httpcode-backend-2xx', 'httpcode-backend-4xx',
'httpcode-backend-5xx', 'httpcode-backend-3xx', 'backendconnectionerrors')

=back

=cut
