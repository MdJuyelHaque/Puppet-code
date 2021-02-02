class nginx (
  $maxPostSize,
  $defaultDocroot = '/var/www',
  $errorPagesDocroot = $defaultDocroot,
  $sslConfigPath = '',
  $sslConfigPrefix = '',
  $cacheRoot = '/var/cache/nginx',
  $logsRoot = '/var/log/nginx',
  $nginxPidFile = "/var/run/nginx.pid",
  $logForwardedClientIp = false,
  $awsRegion = '',
  $secretsAwsAccessKey = '',
  $secretsAwsSecretKey = '',
) {

  # SSL configs dir
  $nginxSslDir = "/etc/nginx/ssl"

  # Auth configs dir
  $nginxAuthDir = "/etc/nginx/auth"

  # Secrets profile up on AWS
  $awsCliProfile = 'authsecrets'

  # Get the number of processors, determines the number of workers
  $numberOfProcessors = inline_template("<% processors = `grep processor /proc/cpuinfo | wc -l` -%><%= processors -%>")

  exec { 'add-nginx-repository':
      path        => '/usr/bin:/bin:/sbin:/usr/sbin',
      command     => 'echo "deb http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" | sudo tee /etc/apt/sources.list.d/nginx.list && curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add - && apt-get update',
      creates     => '/etc/apt/sources.list.d/nginx.list',
      require     => Package['lsb-release', 'gnupg2', 'ca-certificates', 'curl'],
      notify      => Package['nginx']
  }

  package {['nginx', 'apache2-utils']:
    require   => Exec['add-nginx-repository'],
    notify    => File['/etc/nginx/sites-enabled'],
  }

  common::ulimit {"www-data-ulimit": user => "www-data", openFilesLimit => 65536}

  # Create directories and give correct permissions
  common::mkdirs { ["$logsRoot", "$cacheRoot", "$defaultDocroot", "$errorPagesDocroot"]:
    chmodMask   => '0755',
    user        => 'www-data',
    require     => Package['nginx'],
    notify      => File["/etc/nginx/nginx.conf"],
  }

  service { 'nginx':
    name      => 'nginx',
    ensure      => 'running',
    enable      => true,
    hasrestart  => true,
    hasstatus   => true,
    provider    => 'init',
    require     => [Common::Ulimit["www-data-ulimit"], Package['nginx']]
  }

  # Install as a service
  file {'/etc/rc2.d/S99nginx':
      ensure => link,
      target => '/etc/init.d/nginx',
      require => Package['nginx']
  }

  # Error pages
  file {"${errorPagesDocroot}/client-error.html":
      ensure    => 'file',
      mode      => 0444,
      owner     => 'www-data',
      group     => 'www-data',
      source    => "puppet:///modules/nginx/client-error.html",
      require   => Common::Mkdirs["${errorPagesDocroot}"],
  }

  # Error pages
  file {"${errorPagesDocroot}/server-error.html":
      ensure    => 'file',
      mode      => 0444,
      owner     => 'www-data',
      group     => 'www-data',
      source    => "puppet:///modules/nginx/server-error.html",
      require   => Common::Mkdirs["${errorPagesDocroot}"],
  }

  # Healthcheck
  file {"${defaultDocroot}/healthcheck.html":
      ensure    => 'file',
      mode      => 0444,
      owner     => 'www-data',
      group     => 'www-data',
      source    => "puppet:///modules/nginx/healthcheck.html",
      require   => Common::Mkdirs["${defaultDocroot}"],
  }

  # Configure logrotate
  file {"/etc/logrotate.d/nginx":
      ensure    => 'file',
      mode      => 0444,
      owner     => 'root',
      group     => 'root',
      content   => template("nginx/nginx-logrotate.erb"),
      require   => Service['nginx']
  }

  # Remove all enabled sites
  file { '/etc/nginx/sites-enabled':
      ensure    => 'directory',
      mode      => 0444,
      owner     => 'root',
      group     => 'root',
      require   => Package['nginx'],
      notify    => Service['nginx']
  }

  file {"/etc/nginx/nginx.conf":
      ensure    => 'file',
      mode      => 0444,
      owner     => 'root',
      group     => 'root',
      content   => template("nginx/nginx-conf.erb"),
      require   => [Package['nginx'], Common::Mkdirs["$logsRoot", "$cacheRoot", "$defaultDocroot", "$errorPagesDocroot"]],
      notify    => [Service['nginx'], File['/etc/nginx/sites-enabled']]
  }

  file {"/etc/nginx/conf.d/logging.conf":
      ensure    => 'file',
      mode      => 0444,
      owner     => 'root',
      group     => 'root',
      source    => "puppet:///modules/nginx/nginx-logging.conf",
      require   => Package['nginx'],
      notify    => Service['nginx']
  }

  if $sslConfigPath != '' {

    file {"$nginxSslDir":
        ensure    => 'directory',
        mode      => 0555,
        owner     => 'root',
        group     => 'root',
        require   => Package['nginx'],
    }

    common::copyfile {["${sslConfigPrefix}.crt", "${sslConfigPrefix}.key"]:
      target      => "$nginxSslDir",
      sourceRoot  => "$sslConfigPath",
      user        => 'root',
      mode        => 0444,
      require     => File["$nginxSslDir"],
      notify      => Service['nginx']
    }

  }

  file { $nginxAuthDir:
      ensure    => 'directory',
      mode      => 0555,
      owner     => 'root',
      group     => 'root',
      require   => Package['nginx'],
  }

  # If secrets have been set up then we will be using this to extract auth username/passwords
  if $secretsAwsAccessKey != '' {
    # AWS CLI profile for retrieving secret keys from AWS secret store
    aws::cli::profile { $awsCliProfile:
      region        => $awsRegion,
      accessKeyId   => $secretsAwsAccessKey,
      secretKeyId   => $secretsAwsSecretKey,
    }
  }

}