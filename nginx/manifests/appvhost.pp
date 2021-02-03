#
# An NGINX Application server vhost which proxies requests to a backend application server
#
define nginx::appvhost(
	$site = 'default',
	$scheme = 'http',
	$isDefaultServer = true,
	$port = 80,
	$logsRoot,
	$defaultDocroot,
	$errorPagesDocroot,
	$proxyHost,
	$httpProxyPort,
	$httpsProxyPort,
	$appServerHost = 'localhost',
	$appServerHttpPort,
	$appServerHttpsPort,
	$httpsProxyAll = false,
	$httpsProtectedPaths = [],
	$httpsProtectedPathsRegex = [],
	$staticPaths = [],
	$proxyPaths = [],
	$appServerPaths = [],
	$blockPathsRegex = [],
  	$includeFilePaths = [],
	$awsDnsResolution = false,
  	$vpcClassB = 0,
) {
  file {"/etc/nginx/sites-enabled/${site}":
      ensure    => 'file',
      mode      => 0444,
      owner     => 'root',
      group     => 'root',
      content   => template("nginx/nginx-site.erb"),
      notify    => Service['nginx'],
      require	=> File['/etc/nginx/sites-enabled']
  }

}
