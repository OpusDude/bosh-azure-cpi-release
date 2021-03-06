require 'spec_helper'
require "unit/vm_manager/create/shared_stuff.rb"

describe Bosh::AzureCloud::VMManager do
  include_context "shared stuff for vm manager"

  describe "#create" do
    context "when VM is not created" do
      context "and client2.create_virtual_machine raises an normal error" do
        context "and no more error occurs" do
          before do
            allow(client2).to receive(:create_virtual_machine).
              and_raise('virtual machine is not created')
          end

          it "should delete vm and nics and then raise an error" do
            expect(client2).to receive(:delete_virtual_machine).once
            expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).once
            expect(disk_manager).to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name).once
            expect(disk_manager).to receive(:delete_vm_status_files).
              with(storage_account_name, vm_name).once
            expect(client2).to receive(:delete_network_interface).twice

            expect {
              vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
            }.to raise_error /virtual machine is not created/
          end
        end

        context "and an error occurs when deleting nic" do
          before do
            allow(client2).to receive(:create_virtual_machine).
              and_raise('virtual machine is not created')
            allow(client2).to receive(:delete_network_interface).
              and_raise('cannot delete nic')
          end

          it "should delete vm and nics and then raise an error" do
            expect(client2).to receive(:delete_virtual_machine).once
            expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).once
            expect(disk_manager).to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name).once
            expect(disk_manager).to receive(:delete_vm_status_files).
              with(storage_account_name, vm_name).once
            expect(client2).to receive(:delete_network_interface).once

            expect {
              vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
            }.to raise_error /cannot delete nic/
          end
        end
      end

      context "and client2.create_virtual_machine raises an AzureAsynchronousError" do
        context "and AzureAsynchronousError.status is not Failed" do
          before do
            allow(client2).to receive(:create_virtual_machine).
              and_raise(Bosh::AzureCloud::AzureAsynchronousError)
          end

          it "should delete vm and nics and then raise an error" do
            expect(client2).to receive(:delete_virtual_machine).once
            expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).once
            expect(disk_manager).to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name).once
            expect(disk_manager).to receive(:delete_vm_status_files).
              with(storage_account_name, vm_name).once
            expect(client2).to receive(:delete_network_interface).twice

            expect {
              vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
            }.to raise_error { |error|
              expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
              expect(error.inspect).not_to match(/This VM fails in provisioning after multiple retries/)
            }
          end
        end

        context "and AzureAsynchronousError.status is Failed" do
          before do
            allow(client2).to receive(:create_virtual_machine).
              and_raise(Bosh::AzureCloud::AzureAsynchronousError.new('Failed'))
          end

          context "and keep_failed_vms is false in global configuration" do
            context "and use_managed_disks is false" do
              context "and ephemeral_disk does not exist" do
                before do
                  allow(disk_manager).to receive(:ephemeral_disk).
                    and_return(nil)
                end

                it "should delete vm and then raise an error" do
                  expect(client2).to receive(:create_virtual_machine).exactly(3).times
                  expect(client2).to receive(:delete_virtual_machine).exactly(3).times
                  expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).exactly(3).times
                  expect(disk_manager).to receive(:delete_vm_status_files).
                    with(storage_account_name, vm_name).exactly(3).times
                  expect(disk_manager).not_to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name)
                  expect(client2).to receive(:delete_network_interface).twice

                  expect {
                    vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                  }.to raise_error { |error|
                    expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                    expect(error.inspect).not_to match(/This VM fails in provisioning after multiple retries/)
                  }
                end
              end

              context "and ephemeral_disk exists" do
                context "and all the vm resources are deleted successfully" do
                  it "should delete vm and then raise an error" do
                    expect(client2).to receive(:create_virtual_machine).exactly(3).times
                    expect(client2).to receive(:delete_virtual_machine).exactly(3).times
                    expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).exactly(3).times
                    expect(disk_manager).to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name).exactly(3).times
                    expect(disk_manager).to receive(:delete_vm_status_files).
                      with(storage_account_name, vm_name).exactly(3).times
                    expect(client2).to receive(:delete_network_interface).twice

                    expect {
                      vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                    }.to raise_error { |error|
                      expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                      expect(error.inspect).not_to match(/This VM fails in provisioning after multiple retries/)
                    }
                  end
                end

                context "and an error occurs when deleting vm" do
                  before do
                    allow(client2).to receive(:delete_virtual_machine).
                      and_raise('cannot delete the vm')
                  end

                  it "should try to delete vm, then raise an error, but not delete the NICs" do
                    expect(client2).to receive(:create_virtual_machine).once
                    expect(client2).to receive(:delete_virtual_machine).exactly(3).times
                    expect(disk_manager).not_to receive(:delete_disk).with(storage_account_name, os_disk_name)
                    expect(disk_manager).not_to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name)
                    expect(disk_manager).not_to receive(:delete_vm_status_files).
                      with(storage_account_name, vm_name)
                    expect(client2).not_to receive(:delete_network_interface)

                    expect {
                      vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                    }.to raise_error { |error|
                      expect(error.inspect).to match(/cannot delete the vm/)
                      expect(error.inspect).to match(/The VM fails in provisioning but an error is thrown in cleanuping VM/)
                      # If the cleanup fails, then the VM resources have to be kept
                      expect(error.inspect).to match(/This VM fails in provisioning after multiple retries/)
                    }
                  end
                end

                context "and an error occurs when deleting vm for the first time but the vm is deleted successfully after retrying" do
                  before do
                    call_count = 0
                    allow(client2).to receive(:delete_virtual_machine) do
                      call_count += 1
                      call_count == 1 ? raise('cannot delete the vm') : true
                    end
                  end

                  it "should delete vm and then raise an error" do
                    expect(client2).to receive(:create_virtual_machine).exactly(3).times
                    expect(client2).to receive(:delete_virtual_machine).exactly(4).times # Failed once and succeeded 3 times
                    expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).exactly(3).times
                    expect(disk_manager).to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name).exactly(3).times
                    expect(disk_manager).to receive(:delete_vm_status_files).
                      with(storage_account_name, vm_name).exactly(3).times
                    expect(client2).to receive(:delete_network_interface).twice

                    expect {
                      vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                    }.to raise_error { |error|
                      expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                      expect(error.inspect).not_to match(/This VM fails in provisioning after multiple retries/)
                    }
                  end
                end
              end
            end

            context "and use_managed_disks is true" do
              context "and ephemeral_disk does not exist" do
                before do
                  allow(disk_manager2).to receive(:ephemeral_disk).
                    and_return(nil)
                end

                it "should delete vm and then raise an error" do
                  expect(client2).to receive(:create_virtual_machine).exactly(3).times
                  expect(client2).to receive(:delete_virtual_machine).exactly(3).times
                  expect(disk_manager2).to receive(:delete_disk).with(resource_group_name, os_disk_name).exactly(3).times
                  expect(disk_manager2).not_to receive(:delete_disk).with(resource_group_name, ephemeral_disk_name)
                  expect(client2).to receive(:delete_network_interface).twice

                  expect {
                    vm_manager2.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                  }.to raise_error { |error|
                    expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                    expect(error.inspect).not_to match(/This VM fails in provisioning after multiple retries/)
                  }
                end
              end

              context "and ephemeral_disk exists" do
                it "should delete vm and then raise an error" do
                  expect(client2).to receive(:create_virtual_machine).exactly(3).times
                  expect(client2).to receive(:delete_virtual_machine).exactly(3).times
                  expect(disk_manager2).to receive(:delete_disk).with(resource_group_name, os_disk_name).exactly(3).times
                  expect(disk_manager2).to receive(:delete_disk).with(resource_group_name, ephemeral_disk_name).exactly(3).times
                  expect(client2).to receive(:delete_network_interface).twice

                  expect {
                    vm_manager2.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                  }.to raise_error { |error|
                    expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                    expect(error.inspect).not_to match(/This VM fails in provisioning after multiple retries/)
                  }
                end
              end
            end
          end

          context "and keep_failed_vms is true in global configuration" do
            let(:azure_properties_to_keep_failed_vms) {
              mock_azure_properties_merge({
                'keep_failed_vms' => true
              })
            }
            let(:vm_manager_to_keep_failed_vms) { Bosh::AzureCloud::VMManager.new(azure_properties_to_keep_failed_vms, registry_endpoint, disk_manager, disk_manager2, client2, storage_account_manager) }
            let(:azure_properties_managed_to_keep_failed_vms) {
              mock_azure_properties_merge({
                'use_managed_disks' => true,
                'keep_failed_vms'   => true
              })
            }
            let(:vm_manager2_to_keep_failed_vms) { Bosh::AzureCloud::VMManager.new(azure_properties_managed_to_keep_failed_vms, registry_endpoint, disk_manager, disk_manager2, client2, storage_account_manager) }

            context "and use_managed_disks is false" do
              context "and ephemeral_disk does not exist" do
                before do
                  allow(disk_manager).to receive(:ephemeral_disk).
                    and_return(nil)
                end

                it "should not delete vm and then raise an error" do
                  expect(client2).to receive(:create_virtual_machine).exactly(3).times
                  expect(client2).to receive(:delete_virtual_machine).twice
                  expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).twice
                  expect(disk_manager).to receive(:delete_vm_status_files).
                    with(storage_account_name, vm_name).twice
                  expect(disk_manager).not_to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name)
                  expect(client2).not_to receive(:delete_network_interface)

                  expect {
                    vm_manager_to_keep_failed_vms.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                  }.to raise_error { |error|
                    expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                    expect(error.inspect).to match(/This VM fails in provisioning after multiple retries/)
                  }
                end
              end

              context "and ephemeral_disk exists" do
                context "and all the vm resources are deleted successfully" do
                  it "should not delete vm and then raise an error" do
                    expect(client2).to receive(:create_virtual_machine).exactly(3).times
                    expect(client2).to receive(:delete_virtual_machine).twice # CPI doesn't delete the VM for the last time
                    expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).twice
                    expect(disk_manager).to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name).twice
                    expect(disk_manager).to receive(:delete_vm_status_files).
                      with(storage_account_name, vm_name).twice
                    expect(client2).not_to receive(:delete_network_interface)

                    expect {
                      vm_manager_to_keep_failed_vms.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                    }.to raise_error { |error|
                      expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                      expect(error.inspect).to match(/This VM fails in provisioning after multiple retries/)
                    }
                  end
                end

                context "and an error occurs when deleting vm" do
                  before do
                    allow(client2).to receive(:delete_virtual_machine).
                      and_raise('cannot delete the vm')
                  end

                  it "should not delete vm and then raise an error" do
                    expect(client2).to receive(:create_virtual_machine).once
                    expect(client2).to receive(:delete_virtual_machine).exactly(3).times
                    expect(disk_manager).not_to receive(:delete_disk).with(storage_account_name, os_disk_name)
                    expect(disk_manager).not_to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name)
                    expect(disk_manager).not_to receive(:delete_vm_status_files).
                      with(storage_account_name, vm_name)
                    expect(client2).not_to receive(:delete_network_interface)

                    expect {
                      vm_manager_to_keep_failed_vms.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                    }.to raise_error { |error|
                      expect(error.inspect).to match(/cannot delete the vm/)
                      expect(error.inspect).to match(/The VM fails in provisioning but an error is thrown in cleanuping VM/)
                      # If the cleanup fails, then the VM resources have to be kept
                      expect(error.inspect).to match(/This VM fails in provisioning after multiple retries/)
                    }
                  end
                end

                context "and an error occurs when deleting vm for the first time but the vm is deleted successfully after retrying" do
                  before do
                    call_count = 0
                    allow(client2).to receive(:delete_virtual_machine) do
                      call_count += 1
                      call_count == 1 ? raise('cannot delete the vm') : true
                    end
                  end

                  it "should not delete vm and then raise an error" do
                    expect(client2).to receive(:create_virtual_machine).exactly(3).times
                    expect(client2).to receive(:delete_virtual_machine).exactly(3).times # Failed once; succeeded 2 times; CPI should not delete the VM for the last time
                    expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).twice
                    expect(disk_manager).to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name).twice
                    expect(disk_manager).to receive(:delete_vm_status_files).
                      with(storage_account_name, vm_name).twice
                    expect(client2).not_to receive(:delete_network_interface)

                    expect {
                      vm_manager_to_keep_failed_vms.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                    }.to raise_error { |error|
                      expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                      expect(error.inspect).to match(/This VM fails in provisioning after multiple retries/)
                    }
                  end
                end
              end
            end

            context "and use_managed_disks is true" do
              context "and ephemeral_disk does not exist" do
                before do
                  allow(disk_manager2).to receive(:ephemeral_disk).
                    and_return(nil)
                end

                it "should not delete vm and then raise an error" do
                  expect(client2).to receive(:create_virtual_machine).exactly(3).times
                  expect(client2).to receive(:delete_virtual_machine).twice
                  expect(disk_manager2).to receive(:delete_disk).with(resource_group_name, os_disk_name).twice
                  expect(disk_manager2).not_to receive(:delete_disk).with(resource_group_name, ephemeral_disk_name)
                  expect(client2).not_to receive(:delete_network_interface)

                  expect {
                    vm_manager2_to_keep_failed_vms.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                  }.to raise_error { |error|
                    expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                    expect(error.inspect).to match(/This VM fails in provisioning after multiple retries/)
                  }
                end
              end

              context "and ephemeral_disk exists" do
                it "should not delete vm and then raise an error" do
                  expect(client2).to receive(:create_virtual_machine).exactly(3).times
                  expect(client2).to receive(:delete_virtual_machine).twice
                  expect(disk_manager2).to receive(:delete_disk).with(resource_group_name, os_disk_name).twice
                  expect(disk_manager2).to receive(:delete_disk).with(resource_group_name, ephemeral_disk_name).twice
                  expect(client2).not_to receive(:delete_network_interface)

                  expect {
                    vm_manager2_to_keep_failed_vms.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                  }.to raise_error { |error|
                    expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                    expect(error.inspect).to match(/This VM fails in provisioning after multiple retries/)
                  }
                end
              end
            end
          end
        end
      end
    end
  end
end
