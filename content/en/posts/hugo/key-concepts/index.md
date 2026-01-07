---
title: "Key Hugo concepts"
date: "2024-08-16"
description: "A cheatsheet of the sorts for Hugo."
summary: "Key concepts to keep in mind when building websites with Hugo."
categories: ["frameworks"]
tags: ["hugo"]
draft: true
---

Important concepts to keep in mind when working with the Hugo static site generator:

* Custom content for the home page goes into `content/_index.md`.
* Leaf page: a standard content page that does not contain any sub-pages, e.g., an about page or an individual blog post.
* When including assets in a page, e.g., an image, a page bundle should be used. This requires using a sub-directory with an `index.md` file inside it, plus the assets.
* A [page bundle](https://gohugo.io/content-management/page-bundles/) is a directory that encapsulates both content and associated resources.
