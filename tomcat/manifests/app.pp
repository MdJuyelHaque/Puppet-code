define tomcat::app(
	$tomcatHome,
	$tomcatContextXmlErbTemplate = undef,
	$tomcatUser = 'tomcat',
	$webappTomcatId,
	$webappArtifactId,
	$webappGroupId,
	$nexusHost,
	$nexusReleaseRepository,
	$nexusSnapshotRepository,
	$nexusReleaseVersion,
	$tomcatContextXmlTemplateParameters = {},
	$useIndividualContext = true
) {
	$tomcatContextXmlHome = "${tomcatHome}/conf/Catalina/localhost"

    if $tomcatContextXmlErbTemplate != undef {
		if $useIndividualContext {
			$tomcatWebappContextXml = "${tomcatContextXmlHome}/${webappTomcatId}.xml"
		} else {
			$tomcatWebappContextXml = "${tomcatHome}/conf/context.xml"
		}
    	# Tomcat context XML file for the webapp containing the DB details
		file {"${tomcatWebappContextXml}":
		  ensure    => 'file',
		  mode      => 0400,
		  owner     => "${tomcatUser}",
		  group     => "${tomcatUser}",
		  content   => template($tomcatContextXmlErbTemplate),
		  require	=> Common::Mkdirs["${tomcatContextXmlHome}"],
		  notify	=> [Service['tomcat'], Maven::Install_Artifact["$webappArtifactId"]]
		}
	}

    if $nexusReleaseVersion =~ /-SNAPSHOT$/ {
    	$appRepo = $nexusSnapshotRepository
    } else {
    	$appRepo = $nexusReleaseRepository
    }

    # Deploy the webapp
    maven::install_artifact { $webappArtifactId:
      mavenRepoBaseUrl    	=> "${nexusHost}/repository/${appRepo}",
      groupId             	=> "${webappGroupId}",
      artifactVersion     	=> $nexusReleaseVersion,
      artifactExtension		=> "war",
      destination         	=> "${tomcatHome}/webapps",
      finalArtifactName		=> "${webappTomcatId}.war",
      user 				  	=> "${tomcatUser}",
      notify				=> Service['tomcat'],
    }

}
