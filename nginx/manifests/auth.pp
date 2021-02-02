define nginx::auth(
  $authFileDir,
	$passwordFile,
	$username,
	$password
) {

  exec { "add-user-password-to-htaccess-file-${name}":
      path 			=> '/usr/bin:/bin:/sbin:/usr/sbin',
      command     => "htpasswd -b ${authFileDir}/${passwordFile} ${username} ${password}",
      creates 		=> "${authFileDir}/${passwordFile}",
      provider 		=> 'shell',
      onlyif  		=> "test -e ${authFileDir}/${passwordFile}",
      require     => [File[$authFileDir], Package['apache2-utils']]
  }

  exec { "create-htaccces-file-with-user-password-${authFileDir}-${passwordFile}":
      path 			=> '/usr/bin:/bin:/sbin:/usr/sbin',
      command 		=> "htpasswd -b -c ${authFileDir}/${passwordFile} ${username} ${password}",
      creates     => "${authFileDir}/${passwordFile}",
      provider 		=> 'shell',
      unless  		=> "test -e ${authFileDir}/${passwordFile}",
      require     => [File[$authFileDir], Package['apache2-utils']]
  }

}