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

package cloud::aws::cloudwatch::mode::getmap;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                {
                                    "region:s"            => { name => 'region' },
                                });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (!defined($self->{option_results}->{region}) || $self->{option_results}->{region} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --region option.");
        $self->{output}->option_exit();
    }
}

sub run {
    my ($self, %options) = @_;

    my @infra;

    my $vpcs = $options{custom}->get_map(region => $self->{option_results}->{region}, service => 'ec2', command => 'describe-vpcs');
    my $instances = $options{custom}->get_map(region => $self->{option_results}->{region}, service => 'ec2', command => 'describe-instances');
    my $db_instances = $options{custom}->get_map(region => $self->{option_results}->{region}, service => 'rds', command => 'describe-db-instances');
    my $load_balancers = $options{custom}->get_map(region => $self->{option_results}->{region}, service => 'elb', command => 'describe-load-balancers');

    # VPC
    foreach my $vpc (@{$vpcs->{Vpcs}}) {
        next if (!defined($vpc->{VpcId}));
        my %vpc;
        $vpc{id} = $vpc->{VpcId};
        foreach my $tag (@{$vpc->{Tags}}) {
            if ($tag->{Key} eq "Name" && defined($tag->{Value})) {
                $vpc{name} = $tag->{Value};
            }
        }
        push @infra, \%vpc;
    }

    # EC2
    foreach my $reservation (@{$instances->{Reservations}}) {
        foreach my $instance (@{$reservation->{Instances}}) {
            next if (!defined($instance->{InstanceId}));
            my %ec2;
            $ec2{id} = $instance->{InstanceId};
            foreach my $tag (@{$instance->{Tags}}) {
                if ($tag->{Key} eq "aws:autoscaling:groupName" && defined($tag->{Value})) {
                    $ec2{asg} = $tag->{Value};
                }
                if ($tag->{Key} eq "Name" && defined($tag->{Value})) {
                    $ec2{name} = $tag->{Value};
                }
            }
            foreach my $vpc (@infra) {
                next if (defined($instance->{VpcId}) && $instance->{VpcId} ne '' && $vpc->{id} !~ /$instance->{VpcId}/);
                push @{$vpc->{ec2}}, \%ec2;
            }
        }
    }

    # RDS
    foreach my $db_instance (@{$db_instances->{DBInstances}}) {
        next if (!defined($db_instance->{DbiResourceId}));
        my %rds;
        $rds{id} = $db_instance->{DbiResourceId};
        $rds{name} = $db_instance->{DBInstanceIdentifier};
        foreach my $vpc (@infra) {
            next if (defined($db_instance->{DBSubnetGroup}->{VpcId}) && $db_instance->{DBSubnetGroup}->{VpcId} ne '' && $vpc->{id} !~ /$db_instance->{DBSubnetGroup}->{VpcId}/);
            push @{$vpc->{rds}}, \%rds;
        }
    }

    # ELB
    foreach my $load_balancers (@{$load_balancers->{LoadBalancerDescriptions}}) {
        next if (!defined($load_balancers->{LoadBalancerName}));
        my %elb;
        $elb{name} = $load_balancers->{LoadBalancerName};
        foreach my $vpc (@infra) {
            next if (defined($load_balancers->{VPCId}) && $load_balancers->{VPCId} ne '' && $vpc->{id} !~ /$load_balancers->{VPCId}/);
            push @{$vpc->{elb}}, \%elb;
        }
    }

    if (centreon::plugins::misc::mymodule_load(no_quit => 1, module => 'JSON',
                                            error_msg => "Cannot load module 'JSON'.")) {
        print "Cannot load module 'JSON'\n";
        $self->exit(exit_litteral => 'unknown');
    }
    $self->{json_output} = JSON->new->utf8();
    # $self->{output}->output_add(long_msg => sprintf("%s", $self->{json_output}->encode(\@infra)));
    # $self->{output}->display();
    # $self->{output}->exit();
    print $self->{json_output}->encode(\@infra);
}

1;

__END__

=head1 MODE

Get AWS mapping

=over 8

=back

=cut
