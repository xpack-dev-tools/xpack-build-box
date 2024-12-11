---
title: The xPack Build Box releases
permalink: /xbb/releases/

search: exclude
github_editme: false

comments: false
toc: false

date: 2021-10-13 12:33:00 +0300

---

___
{% for post in site.posts %}{% if post.categories contains "releases" %}{% if post.categories contains "xbb" %}
* [{{ post.title }}]({{ site.baseurl }}{{ post.url }}) [(download)]({{ post.download_url }}){% endif %}{% endif %}{% endfor %}
