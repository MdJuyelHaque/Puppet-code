#
# An NGINX Application server HTTPS vhost which proxies requests to a backend application server
#
define nginx::appvhostssl(
  $site = 'default-ssl',
  $scheme = 'https',
  $isDefaultServer = true,
  $port = 443,
  $logsRoot,
  $defaultDocroot,
  $errorPagesDocroot,
  $proxyHost,
  $httpProxyPort,
  $httpsProxyPort,
  $nginxSslDir,
  $sslConfigPrefix,
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
      content   => template("nginx/nginx-ssl-site.erb"),
      notify    => Service['nginx'],
      require   => File['/etc/nginx/sites-enabled']
  }

}
