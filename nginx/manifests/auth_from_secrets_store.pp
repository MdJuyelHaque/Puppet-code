class nginx::auth_from_secrets_store(
	$usernames,
	$profile,
	$awsSecretPath,
	$authFileDir,
	$passwordFile
) {

	$authSecretsExecutable = '/var/local/auth-from-secrets.sh'

	file{ $authSecretsExecutable:
      ensure  	=> present,
      owner   	=> 'root',
      group   	=> 'root',
      mode  	=> '0500',
      source  	=> "puppet:///modules/nginx/auth-from-secrets.sh",
      require	=> Class['aws::cli'],
    }

	# For each key name restore the server keys
	$usernames.each |Integer $index, String $username| {
  		notice("Creating HTTP auth for user ${username}")

		exec { "create-auth-user-${username}":
		  path      => '/usr/bin:/bin:/sbin:/usr/sbin',
		  command   => "${authSecretsExecutable} ${profile} ${awsSecretPath} ${username} ${authFileDir}/${passwordFile}",
		  require 	=> [File[$authSecretsExecutable, $authFileDir], Package['apache2-utils']],
		}
	}

}
