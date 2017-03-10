"""
    Settings for eLife Spectrum
    ~~~~~~~~~~~
    To specify multiple environments, each environment gets its own class,
    and calling get_settings will return the specified class that contains
    the settings.

    You must modify:
        aws_access_key_id
        aws_secret_access_key

"""

class common():
    tmp = '{{ pillar.alfred.spectrum.tmp }}'

class end2end(common):
    aws_access_key_id = '{{ pillar.alfred.spectrum.end2end.aws.access_key_id }}'
    aws_secret_access_key = '{{ pillar.alfred.spectrum.end2end.aws.secret_access_key }}'
    bucket_input = '{{ pillar.alfred.spectrum.end2end.bot.bucket.input }}' 
    bucket_eif = '{{ pillar.alfred.spectrum.end2end.bot.bucket.eif }}'
    bucket_cdn = '{{ pillar.alfred.spectrum.end2end.bot.bucket.cdn }}'
    bucket_archive = '{{ pillar.alfred.spectrum.end2end.bot.bucket.archive }}'
    bucket_published = '{{ pillar.alfred.spectrum.end2end.bot.bucket.published }}'
    bucket_silent_corrections = '{{ pillar.alfred.spectrum.end2end.bot.bucket.silent_corrections }}'
    queue_workflow_starter = '{{ pillar.alfred.spectrum.end2end.bot.queue.workflow_starter }}'
    website_host = '{{ pillar.alfred.spectrum.end2end.website.host }}'
    website_user = '{{ pillar.alfred.spectrum.end2end.website.user }}'
    website_password = '{{ pillar.alfred.spectrum.end2end.website.password }}'
    dashboard_host = '{{ pillar.alfred.spectrum.end2end.dashboard.host }}'
    dashboard_user = '{{ pillar.alfred.spectrum.end2end.dashboard.user }}'
    dashboard_password = '{{ pillar.alfred.spectrum.end2end.dashboard.password }}'
    lax_host = '{{ pillar.alfred.spectrum.end2end.lax.host }}'
    api_gateway_host = '{{ pillar.alfred.spectrum.end2end.api_gateway.host }}'
    journal_host = '{{ pillar.alfred.spectrum.end2end.journal.host }}'
    journal_cms_host = '{{ pillar.alfred.spectrum.end2end.journal_cms.host }}'
    journal_cms_user = '{{ pillar.alfred.spectrum.end2end.journal_cms.user }}'
    journal_cms_password = '{{ pillar.alfred.spectrum.end2end.journal_cms.password }}'
    region_name = '{{ pillar.alfred.spectrum.end2end.aws.region }}'
    github_article_xml_repository_url = '{{ pillar.alfred.spectrum.end2end.github.article_xml_repository_url }}'

class continuumtest(common):
    aws_access_key_id = '{{ pillar.alfred.spectrum.continuumtest.aws.access_key_id }}'
    aws_secret_access_key = '{{ pillar.alfred.spectrum.continuumtest.aws.secret_access_key }}'
    bucket_input = '{{ pillar.alfred.spectrum.continuumtest.bot.bucket.input }}' 
    bucket_eif = '{{ pillar.alfred.spectrum.continuumtest.bot.bucket.eif }}'
    bucket_cdn = '{{ pillar.alfred.spectrum.continuumtest.bot.bucket.cdn }}'
    bucket_archive = '{{ pillar.alfred.spectrum.continuumtest.bot.bucket.archive }}'
    bucket_published = '{{ pillar.alfred.spectrum.continuumtest.bot.bucket.published }}'
    bucket_silent_corrections = '{{ pillar.alfred.spectrum.continuumtest.bot.bucket.silent_corrections }}'
    queue_workflow_starter = '{{ pillar.alfred.spectrum.continuumtest.bot.queue.workflow_starter }}'
    website_host = '{{ pillar.alfred.spectrum.continuumtest.website.host }}'
    website_user = '{{ pillar.alfred.spectrum.continuumtest.website.user }}'
    website_password = '{{ pillar.alfred.spectrum.continuumtest.website.password }}'
    dashboard_host = '{{ pillar.alfred.spectrum.continuumtest.dashboard.host }}'
    dashboard_user = '{{ pillar.alfred.spectrum.continuumtest.dashboard.user }}'
    dashboard_password = '{{ pillar.alfred.spectrum.continuumtest.dashboard.password }}'
    lax_host = '{{ pillar.alfred.spectrum.continuumtest.lax.host }}'
    api_gateway_host = '{{ pillar.alfred.spectrum.continuumtest.api_gateway.host }}'
    journal_host = None
    region_name = '{{ pillar.alfred.spectrum.continuumtest.aws.region }}'
    github_article_xml_repository_url = None


def get_settings(env):
    """
    Return the settings class based on the environment type provided,
    by default use the end2end environment settings
    """
    return eval(env)
