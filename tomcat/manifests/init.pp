class tomcat(
	$environment = 'local-dev',
	$isLocal,
	$nexusHost,
	$tomcatInstallHome = "${installHome}/tomcat",
	$httpPort,
	$httpsPort,
	$httpProxyPort,
	$httpsProxyPort,
	$maxPostSize,
	$tomcatUsername,
	$tomcatPassword,
	$connectionTimeout = 30000,
	$tomcatUser = 'tomcat',
	$debugPort = 8088,
	$jmxPort = 9011,
	$maxMemory = '2g',
	$maxMetaspace = '512m',
	$jolokiaAgentPort
) {

	$downloadDestination = "/tmp"
	$tomcatMajorVersion="9"
	$tomcatVersion="${tomcatMajorVersion}.0.39"
	$tomcatBinName = "apache-tomcat-${tomcatVersion}.zip"
	$tomcatBinUrl = "${nexusHost}/repository/infrastructure-assets/apache-tomcat/${tomcatMajorVersion}/${tomcatBinName}"
	$tomcatHome="${tomcatInstallHome}/apache-tomcat-${tomcatVersion}"
	$tomcatContextXmlHome = "${tomcatHome}/conf/Catalina/localhost"
	$tomcatJolokiaAgentConf = "${tomcatHome}/jolokia-tomcat-agent.conf"

	# Work out an ideal JVM size for our process based on % of total memory
	if $isLocal {
		$percentageMemoryToUse = 0.4
	} else {
		$percentageMemoryToUse = 0.75
	}
    $jvmMaxSize = inline_template("<%
    	memory = \"2g\"
    	freemem = `/usr/bin/free -m`
    	physicalMemory = freemem.split(\"\\n\")[1]
		physicalMemory.match(/^Mem:\\s*([0-9]+)\\s*/) { |mem|
			memory = (((mem[1].to_f * ${percentageMemoryToUse})/1024) * 1000).to_i.to_s + \"m\"
		}
		-%><%= memory -%>")

	jolokia::config { $tomcatJolokiaAgentConf:
		jolokiaAgentPort 	=> $jolokiaAgentPort,
		owner				=> $tomcatUser,
		require				=> [Class['jolokia'], Exec['uncompress-tomcat']]
	}

	common::download_file { "$tomcatBinName":
		url				=> $tomcatBinUrl,
        cwd				=> $downloadDestination,
        timeout			=> 600,
	}

    exec { 'uncompress-tomcat':
        path        => '/usr/bin:/bin:/sbin:/usr/sbin',
        command     => "unzip -o $downloadDestination/$tomcatBinName -d ${tomcatInstallHome}",
        user        => $tomcatUser,
        require     => [User[$tomcatUser], Common::Download_File["$tomcatBinName"], Package['unzip']]
    }

	common::mkdirs { "${tomcatContextXmlHome}":
	  chmodMask   	=> '0400',
	  user 			=> $tomcatUser,
	  require		=> Exec['uncompress-tomcat']
	}

	exec { 'change-tomcat-bin-perms':
        path        => '/usr/bin:/bin:/sbin:/usr/sbin',
        command     => "chmod 0500 ${tomcatHome}/bin/*.sh",
        user        => $tomcatUser,
        require     => Exec['uncompress-tomcat']
    }

	file {"${tomcatHome}/conf/server.xml":
	  ensure    => 'file',
	  mode      => 0400,
	  owner     => $tomcatUser,
	  group     => $tomcatUser,
	  content   => template("tomcat/server.xml.erb"),
	  require	=> Exec['uncompress-tomcat'],
	  notify	=> Service['tomcat']
	}

	file {"/etc/init.d/tomcat":
	  ensure    => 'file',
	  mode      => 0500,
	  owner     => 'root',
	  group     => 'root',
	  content   => template("tomcat/tomcat-init.erb"),
	}

	service { 'tomcat':
		name      	=> 'tomcat',
		ensure      => 'running',
		enable      => true,
		hasrestart  => true,
		hasstatus   => true,
		provider    => 'init',
		require     => [File["/etc/init.d/tomcat"], Exec['uncompress-tomcat'], Jolokia::Config[$tomcatJolokiaAgentConf]]
	}

	# Install as a service
	file {'/etc/rc2.d/S99tomcat':
	  ensure 	=> link,
	  target 	=> '/etc/init.d/tomcat',
	  require   => [File["/etc/init.d/tomcat"], Exec['uncompress-tomcat']]
	}

	file { "/etc/logrotate.d/tomcat-logs":
	  ensure    => 'file',
	  mode      => 0444,
	  content   => template("tomcat/tomcat-logrotate.erb"),
	  require   => Exec['uncompress-tomcat']
	}

	file { "/var/local/compress-tomcat-logs.sh":
	  ensure    => 'file',
	  mode      => 0500,
	  source 	=> "puppet:///modules/tomcat/compress-tomcat-logs.sh",
	  require   => Exec['uncompress-tomcat']
	}

	common::cronjob{ 'tomcat-compress-logs-job':
		cron      => "30 0 * * * root /var/local/compress-tomcat-logs.sh ${tomcatHome}/logs",
		require   => File['/var/local/compress-tomcat-logs.sh']
	}

	if $environment != 'local-dev' {

		# Not in local dev: Delete all of the installed webapps
		exec { 'remove-default-webapps':
	        path        => '/usr/bin:/bin:/sbin:/usr/sbin',
	        command     => "rm -rf ${tomcatHome}/webapps/docs ${tomcatHome}/webapps/examples ${tomcatHome}/webapps/host-manager ${tomcatHome}/webapps/manager ${tomcatHome}/webapps/ROOT",
	        require		=> Exec['uncompress-tomcat'],
	        notify		=> Service['tomcat']
	    }

	} else {
		# In local dev: Allow users to use the manager webapp

		# Create users for the manager webapp
		file {"${tomcatHome}/conf/tomcat-users.xml":
		  ensure    => 'file',
		  mode      => 0644,
		  owner     => $tomcatUser,
		  group     => $tomcatUser,
		  content   => template("tomcat/tomcat-users.xml.erb"),
		  require	=> Exec['uncompress-tomcat'],
		  notify	=> Service['tomcat']
		}

		# Enable the manager webapp
		file {"${tomcatHome}/webapps/manager/META-INF/context.xml":
		  ensure    => 'file',
		  mode      => 0400,
		  owner     => $tomcatUser,
		  group     => $tomcatUser,
		  source 	=> "puppet:///modules/tomcat/manager-webapp-context.xml",
		  require	=> Exec['uncompress-tomcat'],
		  notify	=> Service['tomcat']
		}

		# Enable JMX
		file {"${tomcatHome}/bin/setenv.sh":
		  ensure    => 'file',
		  mode      => 0600,
		  owner     => $tomcatUser,
		  group     => $tomcatUser,
		  content   => template("tomcat/setenv.sh.erb"),
		  require	=> Exec['uncompress-tomcat'],
		  notify	=> Service['tomcat']
		}

	}

}