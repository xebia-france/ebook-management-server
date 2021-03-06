# encoding: UTF-8
require 'spec_helper'

home_dir = '/home/calibre'
library_dir = "#{home_dir}/library"

lang = 'en_US.utf8'
lc_all = 'en_US.utf8'
language = 'en_US.utf8'

describe 'ebook-management-server::default' do
  let(:chef_run) do
    runner = ChefSpec::Runner.new(
      log_level: :error
    )
    Chef::Config.force_logger true
    runner.converge('recipe[ebook-management-server::default]')
  end

  # Stubbing for test of 'Update Locale'
  let(:etc_default_locale_content) do
    <<-CONTENT
    LANG="en_US.utf8"
    LANGUAGE="en_US:"
    CONTENT
  end

  before do
    allow(IO).to receive_message_chain(:read).and_call_original
    allow(IO).to receive_message_chain(:read).with('/etc/default/locale').and_return(etc_default_locale_content)
  end

  it 'Sets the system locale properly' do
    expect(chef_run).to run_execute('Update locale').with(
      command: "update-locale LANG=#{lang} LC_ALL=#{lc_all} LANGUAGE=#{language}",
      user: 'root'
    )
  end

  %w(libtool fontconfig libxt6 libltdl7 vim).each do |pkg|
    it "installs #{pkg} package" do
      expect(chef_run).to install_package(pkg)
    end
  end

  it 'creates a calibre group' do
    expect(chef_run).to create_group('calibre')
  end

  it 'creates a calibre user' do
    expect(chef_run).to create_user('calibre').with(
      comment: 'User to Run Calibre',
      home: home_dir,
      system: true,
      gid: 'calibre'
    )
  end

  it 'creates remote_file calibre-linux-installer.py with correct mode' do
    expect(chef_run).to create_remote_file_if_missing('/usr/local/bin/calibre-linux-installer.py').with(mode: '0544')
  end

  it 'runs the calibre-linux-installer.py script' do
    expect(chef_run).to run_execute('/usr/local/bin/calibre-linux-installer.py')
  end

  it 'creates a service for calibre' do
    resource = chef_run.service('calibre-server')
    expect(resource).to do_nothing
  end

  it 'creates calibre start/stop script and starts the calibre content server as user calibre' do
    expect(chef_run).to create_cookbook_file('/etc/init.d/calibre-server').with(
      source: 'calibre-server.sh',
      owner: 'root',
      group: 'root',
      mode: '0755'
    )
    calibre_script_resource = chef_run.cookbook_file('/etc/init.d/calibre-server')
    expect(calibre_script_resource).to notify('service[calibre-server]').to(:enable).delayed
  end

  it 'Adds an empty test book to the library' do
    expect(chef_run).to run_execute('Adding an empty test book to the library').with(
      command: "calibredb add --title 'Empty Test Book' --empty test-book --with-library #{library_dir}",
      user: 'calibre'
    )
  end
end
