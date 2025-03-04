{% from slspath + "/map.jinja" import resolver with context %}

{% set is_resolvconf_enabled = resolver.resolvconf.enabled and not resolver.resolvconf.remove %}

{{ sls }}~pkg:
  {% if is_resolvconf_enabled %}
  pkg.installed:
  {% else %}
  pkg.purged:
  {% endif %}
    - name: resolvconf
    - require_in:
      - file: {{ sls }}~update-resolv.conf-file

{{ sls }}~update-resolv.conf-file:
  file.managed:
    {% if is_resolvconf_enabled %}
    - name: {{ resolver.resolvconf.base_path }}
    {% else %}
    - name: {{ resolver.resolvconf.file }}
    - follow_symlinks: False
    {% endif %}
    - user: {{ resolver.user }}
    - group: {{ resolver.group }}
    - mode: '0644'
    - source: salt://{{ slspath }}/templates/resolv.conf.jinja
    - template: jinja
    - defaults:
        nameservers: {{ resolver.nameservers | yaml }}
        searchpaths: {{ resolver.searchpaths | yaml }}
        options: {{ resolver.options | yaml }}
        domain: {{ resolver.domain | yaml }}

{% if is_resolvconf_enabled %}
{{ sls }}~update-resolvconf:
  file.symlink:
    - name: /etc/resolv.conf
    - target: {{ resolver.conf_path }}
    - force: True
  cmd.run:
    - name: resolvconf -u
    - onchanges:
      - file: {{ sls }}~update-resolv.conf-file
{% endif %}

# Prevent NetworkManager from managing resolv.conf file.
{% if salt['file.file_exists'](resolver.networkmanager.file) and resolver.networkmanager.managed %}
{{ sls }}~networkmanager_dns:
  ini.options_present:
    - name: {{ resolver.networkmanager.file }}
    - separator: '='
    - strict: False
    - sections:
        main:
          dns: {{ resolver.networkmanager.dns }}
    - onlyif: systemctl is-enabled {{ resolver.networkmanager.service }}
    - require:
      - file: {{ sls }}~update-resolv.conf-file
    - watch_in:
      - service: {{ sls }}~networkmanager_dns
  service.running:
    - name: {{ resolver.networkmanager.service }}
    - enable: True
{% endif %}
