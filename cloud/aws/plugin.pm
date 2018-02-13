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

package cloud::aws::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_custom);

sub new {
    my ( $class, %options ) = @_;
    my $self = $class->SUPER::new( package => __PACKAGE__, %options );
    bless $self, $class;

    $self->{version} = '0.1';
    %{ $self->{modes} } = (
        'cloudwatch-get-alarms'     => 'cloud::aws::cloudwatch::mode::getalarms',
        'cloudwatch-get-metrics'    => 'cloud::aws::cloudwatch::mode::getmetrics',
        'cloudwatch-list-metrics'   => 'cloud::aws::cloudwatch::mode::listmetrics',
        'ec2-cpu'                   => 'cloud::aws::ec2::mode::cpu',
        'ec2-disk'                  => 'cloud::aws::ec2::mode::disk',
        'ec2-network'               => 'cloud::aws::ec2::mode::network',
        'ec2-status'                => 'cloud::aws::ec2::mode::status',
        'ec2-instance-status'       => 'cloud::aws::ec2::mode::instancestatus',
        'elb-http-codes'            => 'cloud::aws::elb::mode::httpcodes',
        'elb-instance-health'       => 'cloud::aws::elb::mode::instancehealth',
        'elb-performances'          => 'cloud::aws::elb::mode::performances',
        'elb-queues'                => 'cloud::aws::elb::mode::queues',
        'rds-instance-status'       => 'cloud::aws::rds::mode::instancestatus',
    );

    $self->{custom_modes}{paws} = 'cloud::aws::custom::paws';
    $self->{custom_modes}{awscli} = 'cloud::aws::custom::awscli';
    return $self;
}

1;

__END__

=head1 PLUGIN DESCRIPTION

Check Amazon AWS cloud.

=cut
