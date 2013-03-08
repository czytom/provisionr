require 'singleton'
require 'net/ftp'
require 'digest'


class Stage3
  include Singleton

  STAGE_DIR = '/var/stages'
  @@arch = 'amd64'
  @@ftp_mirror = 'de-mirror.org'
  @@ftp_port = 21
  @@downloaded = false
  @@ftp_passive = true
  @@verbose = true
  @@test_only = false
  @@ftp_url = "gentoo/releases/#{@@arch}/current-stage3/"

  def self.ftp_url
    @@ftp_url
  end

  def initialize
    @@ftp = Net::FTP.new
    puts "connecting to #{@@ftp_mirror}" if verbose?
    @@ftp.connect(@@ftp_mirror, @@ftp_port)
    @@ftp.login
    @@ftp.chdir @@ftp_url
    @@ftp.passive = @@ftp_passive

    dir = @@ftp.getdir
    @@date = dir.split('/').last
  end

  def fetch_digest
    @@ftp.get stage3_file + '.DIGESTS'
  end

  #TODO get right checksum from file
  def check_digest
    puts "matching digest" if verbose?
    puts digest_get = IO.readlines("#{stage3_file}.DIGESTS")[1].split.first
    puts digest_count = Digest::SHA512.file(stage3_file).hexdigest

    raise "digest not match"  unless digest_count == digest_get
    puts "digest match" if verbose?
  end

  def downloaded?
    if File.exist?(stage3_file)
      puts "File #{stage3_file} downloaded" if verbose?
      return true
    else
      puts "File #{stage3_file} needs to be downloaded" if verbose?
      return false
    end
  end

  def stage3_file
    "stage3-#{@@arch}-#{@@date}.tar.bz2"
  end

  def fetch_stage3
    @@ftp.get stage3_file
    puts "getting #{stage3_file}" if verbose?
    puts "done" if verbose?
  end

  def fetch_and_unpack(destination)
    fetch_digest
    fetch_stage3 unless downloaded?
    check_digest
    unpack(destination)
  end

  def unpack(dest_dir)
    puts  "unpacking stage3" if verbose?
    if dest_dir.match(/^\/mnt.*/)
      system("tar -xjpvf #{stage3_file} -C  #{dest_dir}")
    else
      puts 'chroot_dir have to begins with /mnt'
    end
  end
  
  def verbose?
    @@verbose
  end
end
