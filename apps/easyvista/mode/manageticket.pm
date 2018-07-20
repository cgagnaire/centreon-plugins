#
# Copyright 2017 Centreon (http://www.centreon.com/)
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

package apps::easyvista::mode::manageticket;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use JSON;
use centreon::plugins::http;

sub new {
	my ($class, %options) = @_;
	my $self = $class->SUPER::new(package => __PACKAGE__, %options);
	bless $self, $class;

	$self->{version} = '2.0';
	$options{options}->add_options(arguments =>
		{
			"host-name:s"                       => { name => 'host_name' },
			"host-state:s"                      => { name => 'host_state' },
			"host-output:s"                     => { name => 'host_output' },
			"host-severity:s"                   => { name => 'host_severity' },
			"host-macro-value:s"                => { name => 'host_macro_value' },
			"service-description:s"             => { name => 'service_description' },
			"service-state:s"                   => { name => 'service_state' },
			"service-output:s"                  => { name => 'service_output' },            
			"service-severity:s"                => { name => 'service_severity' },
			"service-macro-value:s"             => { name => 'service_macro_value' },
			"macro-name:s"                      => { name => 'macro_name' },
			"code:s"                            => { name => 'code' },
			"maximum-severity:s"                => { name => 'maximum_severity' },
			"open-ticket-threshold:s"           => { name => 'open_ticket_threshold', default => '^CRITICAL$|^WARNING$|^DOWN$' },
			"close-ticket-threshold:s"          => { name => 'close_ticket_threshold', default => '^OK$|^UP$' },
			"no-close"                          => { name => 'no_close' },
			"centreon-user:s"                   => { name => 'centreon_user' },
			"centreon-engine-cmd:s"             => { name => 'centreon_engine_cmd', default => "/var/lib/centreon-engine/rw/centengine.cmd" },
			"api-proto:s"						=> { name => 'api_proto' },
			"api-hostname:s"                 	=> { name => 'api_hostname' },
			"api-url:s"                 	 	=> { name => 'api_url', default => '/centreon/api/index.php' },
			"api-username:s"               	  	=> { name => 'api_username' },
			"api-password:s"                    => { name => 'api_password' },
			"ev-hostname:s"                     => { name => 'ev_hostname' },
			"port:s"                            => { name => 'port' },
			"proto:s"                           => { name => 'proto' },
			"urlpath:s"                         => { name => 'url_path', default => "/WebService/SmoBridge.php" },
			"proxyurl:s"                        => { name => 'proxyurl' },
			"proxypac:s"                        => { name => 'proxypac' },
			"ssl-opt:s@"  						=> { name => 'ssl_opt' },
			"ev-login:s"                        => { name => 'ev_login' },
			"ev-password:s"                     => { name => 'ev_password' },
			"ev-account:s"                      => { name => 'ev_account' },
			"ev-catalog-guid:s"                 => { name => 'ev_catalog_guid', default => "" },
			"ev-catalog-code:s"                 => { name => 'ev_catalog_code', default => "" },
			"ev-asset-id:s"                     => { name => 'ev_asset_id', default => "" },
			"ev-asset-tag:s"                    => { name => 'ev_asset_tag', default => "" },
			"ev-asset-name:s"                   => { name => 'ev_asset_name', default => "" },
			"ev-urgency-id:s"                   => { name => 'ev_urgency_id', default => "" },
			"ev-severity-id:s"                  => { name => 'ev_severity_id', default => "" },
			"ev-external-reference:s"           => { name => 'ev_external_reference', default => "" },
			"ev-phone:s"                        => { name => 'ev_phone', default => "" },
			"ev-requestor-id:s"                 => { name => 'ev_requestor_id', default => "" },
			"ev-requestor-mail:s"               => { name => 'ev_requestor_mail', default => "" },
			"ev-requestor-name:s"               => { name => 'ev_requestor_name', default => "" },
			"ev-location-id:s"                  => { name => 'ev_location_id', default => "" },
			"ev-location-code:s"                => { name => 'ev_location_code', default => "" },
			"ev-department-id:s"                => { name => 'ev_department_id', default => "" },
			"ev-department-code:s"              => { name => 'ev_department_code', default => "" },
			"ev-recipient-id:s"                 => { name => 'ev_recipient_id', default => "" },
			"ev-recipient-identification:s"     => { name => 'ev_recipient_identification', default => "" },
			"ev-recipient-mail:s"               => { name => 'ev_recipient_mail', default => "" },
			"ev-recipient-name:s"               => { name => 'ev_recipient_name', default => "" },
			"ev-origin:s"                       => { name => 'ev_origin', default => '7' },
			"ev-description:s"                  => { name => 'ev_description', default => "" },
			"ev-parent-request:s"               => { name => 'ev_parent_request', default => "" },
			"ev-ci-id:s"                        => { name => 'ev_ci_id', default => "" },
			"ev-ci-asset-tag:s"                 => { name => 'ev_ci_asset_tag', default => "" },
			"ev-ci-name:s"                      => { name => 'ev_ci_name', default => "" },
			"ev-submit-date:s"                  => { name => 'ev_submit_date', default => "" },
			"ev-status-guid:s"                  => { name => 'ev_status_guid', default => "" },
			"ev-end-date:s"                     => { name => 'ev_end_date', default => "" },
			"ev-group-id:s"                     => { name => 'ev_group_id', default => "" },
			"ev-group-mail:s"                   => { name => 'ev_group_mail', default => "" },
			"ev-group-name:s"                   => { name => 'ev_group_name', default => "" },
			"ev-doneby-identification:s"        => { name => 'ev_doneby_identification', default => "" },
			"ev-doneby-mail:s"                  => { name => 'ev_doneby_mail', default => "" },
			"ev-doneby-name:s"                  => { name => 'ev_doneby_name', default => "" },
			"ev-delete-actions:s"               => { name => 'ev_delete_actions', default => "" },
			"timeout:s"                         => { name => 'timeout', default => '20' },
		});

	$self->{http} = centreon::plugins::http->new(output => $self->{output});

  return $self;
}

sub check_options {
	my ($self, %options) = @_;
	$self->SUPER::init(%options);

	if ((!defined($self->{option_results}->{service_severity}) || $self->{option_results}->{service_severity} eq '') && (!defined($self->{option_results}->{host_severity}) || $self->{option_results}->{host_severity} eq '')) {
		$self->{output}->add_option_msg(short_msg => "You need to specify --service-severity or --host-severity options.");
		$self->{output}->option_exit();
	}
	if (!defined($self->{option_results}->{code}) || $self->{option_results}->{code} eq '') {
		$self->{output}->add_option_msg(short_msg => "You need to specify --code option.");
		$self->{output}->option_exit();
	}
	if (!defined($self->{option_results}->{maximum_severity}) || $self->{option_results}->{maximum_severity} eq '') {
		$self->{output}->add_option_msg(short_msg => "You need to specify --maximum-severity option.");
		$self->{output}->option_exit();
	}
	if ((!defined($self->{option_results}->{service_state}) || $self->{option_results}->{service_state} eq '') && (!defined($self->{option_results}->{host_state}) || $self->{option_results}->{host_state} eq '')) {
		$self->{output}->add_option_msg(short_msg => "You need to specify --service-state or --host-state options.");
		$self->{output}->option_exit();
	}
	if (!defined($self->{option_results}->{ev_hostname}) || $self->{option_results}->{ev_hostname} eq '') {
		$self->{output}->add_option_msg(short_msg => "You need to specify --ev-hostname option.");
		$self->{output}->option_exit();
	}
	if (!defined($self->{option_results}->{ev_account}) || $self->{option_results}->{ev_account} eq '') {
		$self->{output}->add_option_msg(short_msg => "You need to specify --ev-account option.");
		$self->{output}->option_exit();
	}
	if (!defined($self->{option_results}->{ev_login}) || $self->{option_results}->{ev_login} eq '') {
		$self->{output}->add_option_msg(short_msg => "You need to specify --ev-login option.");
		$self->{output}->option_exit();
	}
	if (!defined($self->{option_results}->{ev_password}) || $self->{option_results}->{ev_password} eq '') {
		$self->{output}->add_option_msg(short_msg => "You need to specify --ev-password option.");
		$self->{output}->option_exit();
	}
	if (!defined($self->{option_results}->{centreon_user}) || $self->{option_results}->{centreon_user} eq '') {
		$self->{output}->add_option_msg(short_msg => "You need to specify --centreon-user option.");
		$self->{output}->option_exit();
	}
	if (!defined($self->{option_results}->{centreon_engine_cmd}) || $self->{option_results}->{centreon_engine_cmd} eq '') {
		$self->{output}->add_option_msg(short_msg => "You need to specify --centreon-engine-cmd option.");
		$self->{output}->option_exit();
	}

	$self->debug(level => 'INFO', message => 'Starting plugin with parameters:');
	foreach (sort keys $self->{option_results}) {
		$self->debug(level => 'INFO', message => ' ' . $_ . ': ' . $self->{option_results}->{$_}) if (defined($self->{option_results}->{$_}));
	}

	$self->{http}->set_options(%{$self->{option_results}}, hostname => $self->{option_results}->{ev_hostname});
}

sub run {
  	my ($self, %options) = @_;

	my $timestamp = time();

  	if (defined($self->{option_results}->{service_state}) && $self->{option_results}->{service_state} ne '' && defined($self->{option_results}->{service_severity}) && $self->{option_results}->{service_severity} ne '') {
	  	if ($self->{option_results}->{service_severity} < $self->{option_results}->{maximum_severity}) {
		  	if (!defined($self->{option_results}->{no_close}) && defined($self->{option_results}->{service_macro_value}) && $self->{option_results}->{service_macro_value} =~ m/^I[0-9]{6}_[0-9]{4}$/g) {
			  	if ($self->{option_results}->{service_state} =~ m/$self->{option_results}->{close_ticket_threshold}/g) {
					$self->{option_results}->{ev_rfc_number} = $self->{option_results}->{service_macro_value};
					$self->debug(level => 'INFO', message => 'Closing ticket ' . $self->{option_results}->{ev_rfc_number} . ' [host: ' . $self->{option_results}->{host_name} . '] [service: ' . $self->{option_results}->{service_description} . '] [state: ' . $self->{option_results}->{service_state} . ']');
					$self->close_ticket();
					$self->{external_command} = "[".$timestamp."] CHANGE_CUSTOM_SVC_VAR;".$self->{option_results}->{host_name}.";".$self->{option_results}->{service_description}.";".$self->{option_results}->{macro_name}.";\n";
					$self->send_external_command();
			  	}
		  	} else {
			  	if ($self->{option_results}->{service_state} =~ m/$self->{option_results}->{open_ticket_threshold}/g) {
					if (!defined($self->{option_results}->{ev_description}) || $self->{option_results}->{ev_description} eq '') {
						my ($sec,$min,$hour,$wday,$mon,$year) = localtime();
						$self->{option_results}->{ev_description} = 'Incident ouvert automatiquement le '.sprintf("%02d/%02d/%04d", $wday, 1+$mon, 1900+$year).' a '.sprintf("%02d:%02d:%02d", $hour, $min, $sec).'
Host: ' . $self->{option_results}->{host_name} . '
Service: ' . $self->{option_results}->{service_description} . '
Severity: ' . $self->{option_results}->{service_severity} . '
State: ' . $self->{option_results}->{service_state} . '
Output: ' . $self->{option_results}->{service_output};
					}
					$self->debug(level => 'INFO', message => 'Opening ticket [host: ' . $self->{option_results}->{host_name} . '] [service: ' . $self->{option_results}->{service_description} . '] [state: ' . $self->{option_results}->{service_state} . ']');
					$self->open_ticket();
					$self->{external_command} = "[".$timestamp."] CHANGE_CUSTOM_SVC_VAR;".$self->{option_results}->{host_name}.";".$self->{option_results}->{service_description}.";".$self->{option_results}->{macro_name}.";".$self->{soap_return_value}."\n";
					$self->send_external_command();
					$self->{external_command} = "[".$timestamp."] ACKNOWLEDGE_SVC_PROBLEM;".$self->{option_results}->{host_name}.";".$self->{option_results}->{service_description}.";2;1;1;".$self->{option_results}->{centreon_user}.";Ticket EasyVista ".$self->{soap_return_value}."\n";
					$self->send_external_command();
				  	$self->save_history(ticket_id => $self->{soap_return_value}, timestamp => $timestamp, user => $self->{option_results}->{centreon_user},
						subject => 'Service is ' . $self->{option_results}->{service_state},
						link => { hostname => $self->{option_results}->{host_name}, service_description => $self->{option_results}->{service_description}, service_state => $self->{option_results}->{service_state} });
				}
			}
		}
	} elsif (defined($self->{option_results}->{host_state}) && $self->{option_results}->{host_state} ne '' && defined($self->{option_results}->{host_severity}) && $self->{option_results}->{host_severity} ne '') {
		if ($self->{option_results}->{host_severity} < $self->{option_results}->{maximum_severity}) {
			if (!defined($self->{option_results}->{no_close}) && defined($self->{option_results}->{host_macro_value}) && $self->{option_results}->{host_macro_value} =~ m/^I[0-9]{6}_[0-9]{4}$/g) {
				if ($self->{option_results}->{host_state} =~ m/$self->{option_results}->{close_ticket_threshold}/g) {
					$self->{option_results}->{ev_rfc_number} = $self->{option_results}->{host_macro_value};
					$self->debug(level => 'INFO', message => 'Closing ticket ' . $self->{option_results}->{ev_rfc_number} . ' [host: ' . $self->{option_results}->{host_name} . '] [state: ' . $self->{option_results}->{host_state} . ']');
					$self->close_ticket();
					$self->{external_command} = "[".$timestamp."] CHANGE_CUSTOM_HOST_VAR;".$self->{option_results}->{host_name}.";".$self->{option_results}->{macro_name}.";\n";
					$self->send_external_command();
				}
			} else {
				if ($self->{option_results}->{host_state} =~ m/$self->{option_results}->{open_ticket_threshold}/g) {
					if (!defined($self->{option_results}->{ev_description}) || $self->{option_results}->{ev_description} eq '') {
						my ($sec,$min,$hour,$wday,$mon,$year) = localtime();
						$self->{option_results}->{ev_description} = 'Incident ouvert automatiquement le '.sprintf("%02d/%02d/%04d", $wday, 1+$mon, 1900+$year).' a '.sprintf("%02d:%02d:%02d", $hour, $min, $sec).'
Host: ' . $self->{option_results}->{host_name} . '
Severity: ' . $self->{option_results}->{host_severity} . '
State: ' . $self->{option_results}->{host_state} . '
Output: ' . $self->{option_results}->{host_output};
					}
					$self->debug(level => 'INFO', message => 'Opening ticket [host: ' . $self->{option_results}->{host_name} . '] [state: ' . $self->{option_results}->{host_state} . ']');
					$self->open_ticket();
					$self->{external_command} = "[".$timestamp."] CHANGE_CUSTOM_HOST_VAR;".$self->{option_results}->{host_name}.";".$self->{option_results}->{macro_name}.";".$self->{soap_return_value}."\n";
					$self->send_external_command();
					$self->{external_command} = "[".$timestamp."] ACKNOWLEDGE_HOST_PROBLEM;".$self->{option_results}->{host_name}.";2;1;1;".$self->{option_results}->{centreon_user}.";Ticket EasyVista ".$self->{soap_return_value}."\n";
					$self->send_external_command();
					$self->save_history(ticket_id => $self->{soap_return_value}, timestamp => $timestamp, user => $self->{option_results}->{centreon_user},
						subject => 'Host is ' . $self->{option_results}->{host_state},
						link => { hostname => $self->{option_results}->{host_name}, host_state => $self->{option_results}->{host_state} });
				}
			}
		}
	} else {
		$self->debug(level => 'INFO', message => 'Nothing to do');
		$self->{output}->output_add(short_msg => 'Nothing to do');
	}

	$self->{output}->display();
	$self->{output}->exit();
}

sub open_ticket {
	my ($self, %options) = @_;

	$self->{soap_action} = 'tns:EZV_CreateRequest';
	$self->{soap_data} = '<?xml version="1.0"?>
<soap:Envelope
soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
<tns:EZV_CreateRequest xmlns:tns="https://na1.easyvista.com/WebService">
  <tns:Account><![CDATA[' . $self->{option_results}->{ev_account} . ']]></tns:Account>
  <tns:Login><![CDATA[' .$self->{option_results}->{ev_login} . ']]></tns:Login>
  <tns:Password><![CDATA[' . $self->{option_results}->{ev_password} . ']]></tns:Password>
  <tns:Catalog_GUID><![CDATA[' . $self->{option_results}->{ev_catalog_guid} . ']]></tns:Catalog_GUID>
  <tns:Catalog_Code><![CDATA[' . $self->{option_results}->{ev_catalog_code} . ']]></tns:Catalog_Code>
  <tns:AssetID><![CDATA[' . $self->{option_results}->{ev_asset_id} . ']]></tns:AssetID>
  <tns:AssetTag><![CDATA[' . $self->{option_results}->{ev_asset_tag} . ']]></tns:AssetTag>
  <tns:ASSET_NAME><![CDATA[' . $self->{option_results}->{ev_asset_name} . ']]></tns:ASSET_NAME>
  <tns:Urgency_ID><![CDATA[' . $self->{option_results}->{ev_urgency_id} . ']]></tns:Urgency_ID>
  <tns:Severity_ID><![CDATA[' . $self->{option_results}->{ev_severity_id} . ']]></tns:Severity_ID>
  <tns:External_reference><![CDATA[' . $self->{option_results}->{ev_external_reference} . ']]></tns:External_reference>
  <tns:Phone><![CDATA[' . $self->{option_results}->{ev_phone} . ']]></tns:Phone>
  <tns:Requestor_Identification><![CDATA[' . $self->{option_results}->{ev_requestor_id} . ']]></tns:Requestor_Identification>
  <tns:Requestor_Mail><![CDATA[' . $self->{option_results}->{ev_requestor_mail} . ']]></tns:Requestor_Mail>
  <tns:Requestor_Name><![CDATA[' . $self->{option_results}->{ev_requestor_name} . ']]></tns:Requestor_Name>
  <tns:Location_ID><![CDATA[' . $self->{option_results}->{ev_location_id} . ']]></tns:Location_ID>
  <tns:Location_Code><![CDATA[' . $self->{option_results}->{ev_location_code} . ']]></tns:Location_Code>
  <tns:Department_ID><![CDATA[' . $self->{option_results}->{ev_department_id} . ']]></tns:Department_ID>
  <tns:Department_Code><![CDATA[' . $self->{option_results}->{ev_department_code} . ']]></tns:Department_Code>
  <tns:Recipient_ID><![CDATA[' . $self->{option_results}->{ev_recipient_id} . ']]></tns:Recipient_ID>
  <tns:Recipient_Identification><![CDATA[' . $self->{option_results}->{ev_recipient_identification} . ']]></tns:Recipient_Identification>
  <tns:Recipient_Mail><![CDATA[' . $self->{option_results}->{ev_recipient_mail} . ']]></tns:Recipient_Mail>
  <tns:Recipient_Name><![CDATA[' . $self->{option_results}->{ev_recipient_name} . ']]></tns:Recipient_Name>
  <tns:Origin><![CDATA[' . $self->{option_results}->{ev_origin} . ']]></tns:Origin>
  <tns:Description><![CDATA[' . $self->{option_results}->{ev_description} . ']]></tns:Description>
  <tns:ParentRequest><![CDATA[' . $self->{option_results}->{ev_parent_request} . ']]></tns:ParentRequest>
  <tns:CI_ID><![CDATA[' . $self->{option_results}->{ev_ci_id} . ']]></tns:CI_ID>
  <tns:CI_ASSET_TAG><![CDATA[' . $self->{option_results}->{ev_ci_asset_tag} . ']]></tns:CI_ASSET_TAG>
  <tns:CI_NAME><![CDATA[' . $self->{option_results}->{ev_ci_name} . ']]></tns:CI_NAME>
  <tns:SUBMIT_DATE><![CDATA[' . $self->{option_results}->{ev_submit_date} . ']]></tns:SUBMIT_DATE>
</tns:EZV_CreateRequest>
</soap:Body>
</soap:Envelope>';

	$self->call_soap();    

	if ($self->{soap_return_value} =~ m/^-[0-9]+/g) {
		my %map_error = ('-1' => 'invalid Account value', '-2' => 'Login/Password invalid', 
			'-3' => 'invalid parameter', -4 => 'workflow not found');
		my $msg_error = 'unknown error';
		if (defined($map_error{$self->{soap_return_value}})) {
			$msg_error = $map_error{$self->{soap_return_value}};
		}
		$self->debug(level => 'ERROR', message => ' Error calling webservice: ' . $msg_error);
		$self->{output}->output_add(short_msg => "EasyVista error : ".$msg_error);
        $self->{output}->option_exit();
	}

	$self->debug(level => 'INFO', message => 'Ticket opened: ' . $self->{soap_return_value});
	$self->{output}->output_add(short_msg => 'Ticket opened: ' . $self->{soap_return_value});
}

sub close_ticket {
	my ($self, %options) = @_;

	$self->{soap_action} = 'tns:EZV_CloseRequest';
	$self->{soap_data} = '<?xml version="1.0"?>
<soap:Envelope
soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
<tns:EZV_CloseRequest xmlns:tns="https://na1.easyvista.com/WebService">
  <tns:Account><![CDATA[' . $self->{option_results}->{ev_account} . ']]></tns:Account>
  <tns:Login><![CDATA[' .$self->{option_results}->{ev_login} . ']]></tns:Login>
  <tns:Password><![CDATA[' . $self->{option_results}->{ev_password} . ']]></tns:Password>
  <tns:RFC_Number><![CDATA[' . $self->{option_results}->{ev_rfc_number} . ']]></tns:RFC_Number>
  <tns:Catalog_GUID><![CDATA[' . $self->{option_results}->{ev_catalog_guid} . ']]></tns:Catalog_GUID>
  <tns:External_reference><![CDATA[' . $self->{option_results}->{ev_external_reference} . ']]></tns:External_reference>
  <tns:Status_GUID><![CDATA[' . $self->{option_results}->{ev_status_guid} . ']]></tns:Status_GUID>
  <tns:End_Date><![CDATA[' . $self->{option_results}->{ev_end_date} . ']]></tns:End_Date>
  <tns:Group_ID><![CDATA[' . $self->{option_results}->{ev_group_id} . ']]></tns:Group_ID>
  <tns:Group_Mail><![CDATA[' . $self->{option_results}->{ev_group_mail} . ']]></tns:Group_Mail>
  <tns:Groupe_Name><![CDATA[' . $self->{option_results}->{ev_group_name} . ']]></tns:Groupe_Name>
  <tns:DoneBy_identification><![CDATA[' . $self->{option_results}->{ev_doneby_identification} . ']]></tns:DoneBy_identification>
  <tns:DoneBy_Mail><![CDATA[' . $self->{option_results}->{ev_doneby_mail} . ']]></tns:DoneBy_Mail>
  <tns:DoneBy_Name><![CDATA[' . $self->{option_results}->{ev_doneby_name} . ']]></tns:DoneBy_Name>
  <tns:Delete_Actions><![CDATA[' . $self->{option_results}->{ev_delete_actions} . ']]></tns:Delete_Actions>
</tns:EZV_CloseRequest>
</soap:Body>
</soap:Envelope>';

	$self->call_soap();

	if ($self->{soap_return_value} ne '1') {
		my %map_error = ('-1' => 'invalid Account value', '-2' => 'Login/Password invalid', 
			'-3' => 'invalid parameter', -4 => 'workflow not found', -10 => 'end_date format invalid');
		my $msg_error = 'unknown error';
		if (defined($map_error{$self->{soap_return_value}})) {
			$msg_error = $map_error{$self->{soap_return_value}};
		}
		$self->debug(level => 'ERROR', message => ' Error calling webservice: ' . $msg_error);
		$self->{output}->output_add(short_msg => "EasyVista error : ".$msg_error);
        $self->{output}->option_exit();
	}

	$self->debug(level => 'INFO', message => 'Ticket closed: ' . $self->{ev_rfc_number});
	$self->{output}->output_add(short_msg => 'Ticket closed: ' . $self->{ev_rfc_number});
}

# sub update_ticket {
# 	my ($self, %options) = @_;

# 	$self->{soap_action} = 'tns:EZV_UpdateRequest';
# 	$self->{soap_data} = '<?xml version="1.0"?>
# <soap:Envelope
# soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
# xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
# <soap:Body>
# <tns:EZV_UpdateRequest xmlns:tns="https://na1.easyvista.com/WebService">
#   <tns:Account><![CDATA[' . $self->{option_results}->{ev_account} . ']]></tns:Account>
#   <tns:Login><![CDATA[' .$self->{option_results}->{ev_login} . ']]></tns:Login>
#   <tns:Password><![CDATA[' . $self->{option_results}->{ev_password} . ']]></tns:Password>
#   <tns:RFC_Number><![CDATA[' . $self->{option_results}->{ev_rfc_number} . ']]></tns:RFC_Number>
#   <tns:Fields_to_update><![CDATA[{COMMENT=' . $self->{option_results}->{ev_description} . '}]]></tns:Fields_to_update>
#   <tns:External_reference><![CDATA[' . $self->{option_results}->{ev_external_reference} . ']]></tns:External_reference>
# </tns:EZV_UpdateRequest>
# </soap:Body>
# </soap:Envelope>';

# 	$self->call_soap();

# 	if ($self->{soap_return_value} ne '1') {
# 		my %map_error = ('-1' => 'invalid Account value', '-2' => 'Login/Password invalid', 
# 			'-3' => 'invalid parameter', -4 => 'sql query failed');
# 		my $msg_error = 'unknown error';
# 		if (defined($map_error{$self->{soap_return_value}})) {
# 			$msg_error = $map_error{$self->{soap_return_value}};
# 		}
# 		$self->{output}->output_add(short_msg => "EasyVista error : ".$msg_error);
#         $self->{output}->option_exit();
# 	}
# }

sub call_soap {
	my ($self, %options) = @_;

	$self->{http}->add_header(key => 'Content-Type', value => 'text/xml;charset=UTF-8');
	$self->{http}->add_header(key => 'SOAPAction', value => $self->{soap_action});
	$self->{http}->add_header(key => 'Content-Length', value => length($self->{soap_data}));

	eval {
		$self->{soap_response} = $self->{http}->request(method => 'POST', query_form_post => $self->{soap_data});
	};
	if ($@) {
		$self->debug(level => 'ERROR', message => 'Error requesting webservice : ' . $@);
        $self->{output}->add_option_msg(short_msg => "Error requesting webservice" . $@);
        $self->{output}->option_exit();
    }
	$self->{soap_return_value} = ($self->{soap_response} =~ m/<return.*?>(.*?)<\/return>/msi)[0];
}

sub send_external_command {
	my ($self, %options) = @_;

	$self->debug(level => 'INFO', message => 'External command: ' . $self->{external_command});
	open(my $fh, '>', $self->{option_results}->{centreon_engine_cmd});
	print $fh $self->{external_command};
	close $fh;
}

sub save_history {
	my ($self, %options) = @_;
	
	my $token = $self->get_token;

	my $json_request = { ticket_id => $options{ticket_id},
						 timestamp => $options{timestamp},
						 user => $options{user},
						 subject => $options{subject},
						 links => [ $options{link} ] };
    my $encoded;
    eval {
        $encoded = encode_json($json_request);
    };
    if ($@) {
		$self->debug(level => 'ERROR', message => 'Error encoding request');
        $self->{output}->add_option_msg(short_msg => "Cannot encode json request");
        $self->{output}->option_exit();
    }

	$self->debug(level => 'INFO', message => 'Saving history: ' . $encoded);
    $self->{http}->add_header(key => 'Content-Type', value => 'application/json');
    $self->{http}->add_header(key => 'Centreon-Auth-Token', value => $token);
	my $response = $self->{http}->request(method => 'POST',
										query_form_post => $encoded,
										full_url => $self->{option_results}->{api_proto} . '://' . $self->{option_results}->{api_hostname} . $self->{option_results}->{api_url} . '?object=centreon_openticket_history&action=saveHistory',
										hostname => '');

	my $decoded;
    eval {
        $decoded = decode_json($response);
    };
    if ($@) {
        $self->debug(level => 'ERROR', message => 'Error decoding response: ' . $response);
        $self->{output}->add_option_msg(short_msg => "Cannot decode json response");
        $self->{output}->option_exit();
    }

	$self->debug(level => 'INFO', message => 'Response: ' . $decoded->{message});
}

sub get_token {
	my ($self, %options) = @_;

	$self->debug(level => 'INFO', message => 'Getting Centreon API token');
	my $content = $self->{http}->request(method => 'POST',
										post_param => [ 'username=' . $self->{option_results}->{api_username}, 'password=' . $self->{option_results}->{api_password} ],
                                        full_url => $self->{option_results}->{api_proto} . '://' . $self->{option_results}->{api_hostname}. $self->{option_results}->{api_url} . '?action=authenticate',
										hostname => '');
	my $decoded;
    eval {
        $decoded = decode_json($content);
    };
    if ($@) {
        $self->debug(level => 'ERROR', message => 'Error decoding response: ' . $content);
        $self->{output}->add_option_msg(short_msg => "Cannot decode json response");
        $self->{output}->option_exit();
    }

	$self->debug(level => 'INFO', message => 'Token: ' . $decoded->{authToken});
    
    return $decoded->{authToken};
}

sub debug {
	my ($self, %options) = @_;

	$self->{output}->output_add(long_msg => '[' . localtime() . '] [' . $$ . '] [' . $options{level} . '] ' . $options{message}, debug => 1);
}

1;

__END__

=head1 MODE

Manage ticket

=over 8

=item B<--host-name>

Specify host server name (Required).

=item B<--host-state>

Specify host server state (Required).

=item B<--host-output>

Specify host server output message (Required).

=item B<--host-severity>

Specify host server severity level (Required).

=item B<--host-macro-value>

Specify host server macro value to retrieve ticket number (Required).

=item B<--service-description>

Specify service description name (Required).

=item B<--service-state>

Specify service state (Required).

=item B<--service-output>

Specify service output message (Required).

=item B<--service-severity>

Specify serviceseverity level (Required).

=item B<--service-macro-value>

Specify service macro value to retrieve ticket number (Required).

=item B<--macro-name>

Specify macro name to save ticket number (Required).

=item B<--code>

Specify the code enabling ticket management (Required).

=item B<--maximum-severity>

Specify the maximum severity beyond which ticket will not be managed (Required).

=item B<--open-ticket-threshold>

Specify threshold on which ticket will be open (Required) (Default: '^CRITICAL$|^WARNING$|^DOWN$').

=item B<--close-ticket-threshold>

Specify threshold on which ticket will be close (Required) (Default: '^OK$|^UP$').

=item B<--centreon-user>

Specify user to launch external commands (Required).

=item B<--centreon-engine-cmd>

Specify path to centreon engine command pipe (Required) (Default: '/var/lib/centreon-engine/rw/centengine.cmd').

=item B<--ev-hostname>

IP Addr/FQDN of the EasyVista host

=item B<--port>

Port used by EasyVista webservice

=item B<--proto>

Specify https if needed

=item B<--urlpath>

Set path to the webservice (Default: '/WebService/SmoBridge.php')

=item B<--api-proto>

Specify https if needed

=item B<--api-hostname>

IP Addr/FQDN of the Centreon host

=item B<--api-url>

Set path to the Centreon API (Default: '/centreon/api/index.php')

=item B<--api-username>

Specify Centreon account username with API access

=item B<--api-password>

Specify Centreon account password

=item B<--proxyurl>

Proxy URL

=item B<--proxypac>

Proxy pac file (can be an url or local file)

=item B<--ev-account>

Specify account for webservice authentication (Required).

=item B<--ev-login>

Specify login for webservice authentication (Required).

=item B<--ev-password>

Specify password for webservice authentication (Required).

=item B<--ev-catalog-guid>

Specify EasyVista parameter 'Catalog_GUID' (Required).

=item B<--ev-catalog-code>

Specify EasyVista parameter 'Catalog_Code'.

=item B<--ev-asset-id>

Specify EasyVista parameter 'AssetID'.

=item B<--ev-asset-tag>

Specify EasyVista parameter 'AssetTag'.

=item B<--ev-asset-name>

Specify EasyVista parameter 'AssetName'.

=item B<--ev-urgency-id>

Specify EasyVista parameter 'Urgency_ID'.

=item B<--ev-severity-id>

Specify EasyVista parameter 'Severity_ID'.

=item B<--ev-external-reference>

Specify EasyVista parameter 'External_reference'.

=item B<--ev-phone>

Specify EasyVista parameter 'Phone'.

=item B<--ev-requestor-id>

Specify EasyVista parameter 'Requestor_ID'.

=item B<--ev-requestor-mail>

Specify EasyVista parameter 'Requestor_Mail'.

=item B<--ev-requestor-name>

Specify EasyVista parameter 'Requestor_Name'.

=item B<--ev-location-id>

Specify EasyVista parameter 'Location_ID'.

=item B<--ev-location-code>

Specify EasyVista parameter 'Location_Code'.

=item B<--ev-department-id>

Specify EasyVista parameter 'Department_ID'.

=item B<--ev-department-code>

Specify EasyVista parameter 'Department_Code'.

=item B<--ev-recipient-id>

Specify EasyVista parameter 'Recipient_ID'.

=item B<--ev-recipient-identification>

Specify EasyVista parameter 'Recipient_Identification'.

=item B<--ev-recipient-mail>

Specify EasyVista parameter 'Recipient_Mail'.

=item B<--ev-recipient-name>

Specify EasyVista parameter 'Recipient_Name'.

=item B<--ev-origin>

Specify EasyVista parameter 'Origin' (Default: '7').

=item B<--ev-description>

Specify EasyVista parameter 'Description'
  (Default: 'Incident ouvert automatiquement le @date@ a @heure@
			Host: @host-name@
			Service: @service-description@
			Severity : @service-severity@
			State: @service-state@
			Output: @service-output@').

=item B<--ev-parent-request>

Specify EasyVista parameter 'ParentRequest'.

=item B<--ev-ci-id>

Specify EasyVista parameter 'CI_ID'.

=item B<--ev-ci-asset-tag>

Specify EasyVista parameter 'CI_ASSET_TAG'.

=item B<--ev-ci-name>

Specify EasyVista parameter 'CI_NAME'.

=item B<--ev-submit-date>

Specify EasyVista parameter 'SUBMIT_DATE'.

=item B<--ev-status-guid>

Specify EasyVista parameter 'Status_GUID' (Default: 'Closed').

=item B<--ev-end-date>

Specify EasyVista parameter 'End_Date' (Default: 'now').

=item B<--ev-group-id>

Specify EasyVista parameter 'Group_ID'.

=item B<--ev-group-mail>

Specify EasyVista parameter 'Group_Mail'.

=item B<--ev-group-name>

Specify EasyVista parameter 'Groupe_Name'.

=item B<--ev-doneby-identification>

Specify EasyVista parameter 'DoneBy_identification'.

=item B<--ev-doneby-mail>

Specify EasyVista parameter 'DoneBy_Mail'.

=item B<--ev-doneby-name>

Specify EasyVista parameter 'DoneBy_Name'.

=item B<--ev-delete-actions>

Specify EasyVista parameter 'Delete_Actions' (Default: 'False').

=item B<--timeout>

Threshold for HTTP timeout (Default: 20)

=item B<--ssl-opt>

Set SSL Options (Examples: --ssl-opt="SSL_version => TLSv1"
--ssl-opt="SSL_verify_mode => SSL_VERIFY_NONE").

=back

=cut
