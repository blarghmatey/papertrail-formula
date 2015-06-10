{% from "papertrail/map.jinja" import papertrail with context %}

{% set port = salt['pillar.get']('papertrail.port', '') %}
{% set protocol = salt['pillar.get']('papertrail.syslog_protocol', 'tls') %}
{% set subdomain = salt['pillar.get']('papertrail.subdomain', 'logs') %}

{% if salt['pillar.get']('papertrail.use_syslog', True) %}
configure_syslog:
  file.append:
    - name: {{papertrail.syslog_conf_file}}
    - source: salt://papertrail/files/{protocol}_syslog_config.conf
    - context:
        subdomain: {{subdomain}}
        port: ':{{port}}'
    - template: jinja

{% if protocol == 'tls' %}
download_certificate:
  file.managed:
    - name: /etc/papertrail-bundle.pem
    - source: https://papertrailapp.com/tools/papertrail-bundle.pem
    - source_hash: {{ salt['pillar.get']('papertrail.certificate_hash', 'c75ce425e553e416bde4e412439e3d09') }}
{% endif %}

restart_syslog:
  service.running:
    - name: {{papertrail.syslog_service_name}}
    - enable: True
    - watch:
        - file: configure_syslog
{% endif %}

{% if salt['pillar.get']('papertrail.remote_syslog.use', True) %}
{% set version = salt['pillar.get']('papertrail.remote_syslog.version', 'v0.13') %}
{% set md5hash = salt['pillar.get']('papertrail.remote_syslog.md5hash', 'e08f03664bb097cb91c96dd2d4e0f041') %}
download_remote_syslog:
  archive.extracted:
    - name: /opt/
    - source: https://github.com/papertrail/remote_syslog2/releases/download/{{version}}/remote_syslog_linux_amd64.tar.gz
    - source_hash: md5={{md5hash}}
    - archive_format: tar
    - tar_options: z

install_remote_syslog:
  file.rename:
    - name: /usr/local/bin/remote_syslog
    - source: /opt/remote_syslog/remote_syslog

configure_remote_syslog:
  file.managed:
    - name: /etc/log_files.yml
    - source: salt://papertrail/files/remote_syslog_config.yml
    - context:
        files: {{ salt['pillar.get']('papertrail.remote_syslog.app_log_files', []) }}
        exclude_files: {{ salt['pillar.get']('papertrail.remote_syslog.exclude_files', []) }}
        exclude_patterns: {{ salt['pillar.get']('papertrail.remote_syslog.exclude_patterns', []) }}
        subdomain: {{subdomain}}
        port: {{port}}
        protocol: {{protocol}}
        hostname: {{ salt['pillar.get']('papertrail.remote_syslog.hostname') }}

setup_init:
  file.managed:
    - name: {{papertrail.init_file}}
    - source: {{papertrail.init_file_source}}

start_service:
  service.running:
    - name: remote_syslog
    - enable: True
    - watch:
        - file: configure_remote_syslog
{% endif %}