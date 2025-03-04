#####################################
##### Salt Formula For Resolver #####
#####################################
{% from slspath + "/map.jinja" import resolver with context %}

{% set is_resolvconf_enabled = resolver.resolvconf.enabled and not resolver.resolvconf.remove %}

resolvconf-manage:
  {% if is_resolvconf_enabled %}
  pkg.installed:
  {% else %}
  pkg.purged:
  {% endif %}
    - name: resolvconf
    - require_in:
      - file: resolv-file

resolv-file:
  file.managed:
    {% if is_resolvconf_enabled %}
    - name: {{ resolver.resolvconf.base_path }}
    {% else %}
    - name: {{ resolver.resolvconf.file }}
    {% endif %}
    - user: {{ resolver.user }}
    - group: {{ resolver.group }}
    - mode: '0644'
    - source: salt://resolver/files/resolv.conf
    - template: jinja
    - defaults:
        nameservers: {{ resolver.nameservers | yaml }}
        searchpaths: {{ resolver.searchpaths | yaml }}
        options: {{ resolver.options | yaml }}
        domain: {{ resolver.domain | yaml }}

{% if is_resolvconf_enabled %}
resolv-update:
  file.symlink:
    - name: /etc/resolv.conf
    - target: {{ resolver.conf_path }}
    - force: True

  cmd.run:
    - name: resolvconf -u
    - onchanges:
      - file: resolv-file
{% endif %}
