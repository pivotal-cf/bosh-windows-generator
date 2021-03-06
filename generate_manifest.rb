#!/usr/bin/env ruby

require 'yaml'


class GenerateManifest
  def self.run(input_manifest_path, target_type, instances)
    input = YAML.load_file(input_manifest_path)

    output = {
      'name' => 'garden-windows',
      'director_uuid' => input['director_uuid'],
      'update' => input['update'],
      'releases' => [{
        'name'=> 'garden-windows',
        'version'=> 'latest'
      }],
      'stemcells'=> [{
        'os'=> 'windows2012R2',
        'alias'=> 'windows',
        'version'=> 'latest',
      }],
      'instance_groups'=> [{
        'name'=> 'cell_windows',
        'instances'=> instances,
        'lifecycle'=> 'service',
        'jobs'=> [
          {'name'=> 'rep_windows', 'release'=> 'garden-windows'},
          {'name'=> 'consul_agent_windows', 'release'=> 'garden-windows'},
          {'name'=> 'garden-windows', 'release'=> 'garden-windows'},
          {'name'=> 'metron_agent_windows', 'release'=> 'garden-windows'},
          {'name'=> 'hakim', 'release'=> 'garden-windows'},
        ],
        'stemcell'=> 'windows',
      }],
    }

    cells = input['instance_groups'].select { |i| i['name'] == 'diego_cell' }
    if cells.length == 0
      abort 'diego_cell not found in manifest'
    end
    diego_cell = cells[0]
    diego_cell['properties']['diego']['rep']['preloaded_rootfses'] = ['windows2012R2:/tmp/windows2012R2']
    diego_cell['properties']['diego']['ssl']= {'skip_cert_verify'=> true}
    output['instance_groups'][0]['properties'] = diego_cell['properties']
    output['instance_groups'][0]['networks']= [{'name' => 'windows-cells', 'default' => ['dns', 'gateway']}]
    output['instance_groups'][0]['update']= diego_cell['update'] unless diego_cell['update'].nil?
    output['instance_groups'][0]['azs']= diego_cell['azs']

    if target_type == 'vsphere'
      output['instance_groups'][0]['vm_type'] = 'xlarge'
    elsif target_type == 'aws'
      output['instance_groups'][0]['vm_type'] = 'm3.xlarge'
    else
      abort 'Unknown target e.g vsphere,aws'
    end

    return output.to_yaml
  end
end

if __FILE__ == $0
  raise(ArgumentError, "Incorrect number of arguments provided (#{ARGV.length}).\n"\
        "Must provide manifest file and IAAS VM type. Number of cells are optional.\n"\
        "e.g.  ./generate_manifest.rb /tmp/cf.yml vsphere 4") unless ARGV.length >= 2
  instances = 1
  instances = ARGV[2].to_i unless (ARGV[2].nil?)
  raise(ArgumentError, "Number of instances is not an integer") if instances == 0
  puts GenerateManifest.run(ARGV[0], ARGV[1], instances)
end

