---
title: "Build your blog using Hugo and Blowfish"
date: 2024-09-05
lastmod: 2026-08-24
description: "An installation and configuration guide of the Hugo static site generator with the Blowfish theme for your blog website."
summary: "Install and configure the Hugo site generator with the Blowfish theme for your blog website."
categories: ["frameworks"]
tags: ["hugo", "blowfish"]
slug: "blog-with-blowfish"
---

This article will show you how to use [Hugo](https://gohugo.io/) and [Blowfish](https://blowfish.page/) to get your blog up and running from scratch. Hugo is one of the most popular open-source static site generators and Blowfish is a powerful, lightweight theme for Hugo.

We will be using the [Debian](https://www.debian.org) distribution of Linux, but these instructions apply to all Debian derivatives. Moreover, if you are using other distros such as [Fedora](https://fedoraproject.org/), you will only need to change the way you install Git and Hugo.

## System dependencies

In our scenario, the [Git](https://git-scm.com/) distributed version control system is the only tool required. We will use to install the Blowfish theme as a Git submodule, to access [commit information](https://gohugo.io/methods/page/gitinfo/) from a local Git repository, to save a copy of our website on [Github](https://github.com/).

```bash
sudo apt install git
```

## Install Hugo

We will install the extended edition of Hugo, as recommended in their [installation instructions](https://gohugo.io/installation/linux/#editions), using a Debian package that we will download from the [latest release page at Github](https://github.com/gohugoio/hugo/releases/latest). The following set of commands will automate the task (adjust the version in the first line, if needed):

```bash
HUGO_VERSION="0.165.0"
wget https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb \
    --output-document /tmp/hugo_extended_${HUGO_VERSION}_linux-amd64.deb
sudo dpkg --install /tmp/hugo_extended_${HUGO_VERSION}_linux-amd64.deb
rm /tmp/hugo_extended_${HUGO_VERSION}_linux-amd64.deb
```

When in need to upgrade to a newer version of Hugo, we will download a new version of the package and install it, overwriting the existing one.

You can check the installed version with the `hugo version` command.

## Repository

[Create a new repository](https://github.com/new/) on Github.

* Give it a short, memorable name, e.g., `mywebsite`.
* Add a description, e.g., "My personal website using Hugo and Blowfish".
* Make it public or private, depending on your needs.
* Optionally, check the box to add a `README.md` file.
* There is no `.gitignore` template for Hugo on Github, so we will create one later.
* Choose a licence for your project, e.g., AGPL-3.0.

> Github offers some well-crafted guidelines on [how to write a good README file](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes), and on [how to choose a licence for your repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).

Clone the repository to your local machine. We will be using the `~/Sites` parent directory for our projects, but you can choose any other location.

```bash
cd ~/Sites
git clone git@github.com:<username>/mywebsite.git
```

> Refer to the [documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) to learn how to set up SSH access to your Github account.

## Create the site

Creating the Hugo site is a very simple process. Just execute the following command in the root directory of the repository that you just cloned.

```bash
cd ~/Sites/mywebsite
hugo new site . --force
```

## Install Blowfish

We will install Blowfish as a Git submodule, as recommended in their [installation instructions](https://blowfish.page/docs/installation/#install-without-cli). We will be using the latest version of Blowfish from its `main` branch, with shallow depth:

```bash
cd ~/Sites/mywebsite
git submodule add --branch main --depth 1 \
  https://github.com/nunocoracao/blowfish.git themes/blowfish
```

> You can check the maximum Hugo version supported by the theme in its `config.toml` file and adjust your Hugo version accordingly.

When in need to upgrade to a newer version of the theme, use the following Git command at the root directory of the website.

```bash
cd ~/Sites/mywebsite
git submodule update --remote --merge
```

After updating the submodule, we still need to stage and commit the changes:

```bash
git add themes/blowfish
git commit -m "chore: bump Blowfish to version x.y.z""
```

> Once the submodule has been updated, the site needs to be rebuilt.

Mark the submodule as shallow, so only the latest revision is downloaded when cloning the repository again in the future:

```bash
cd ~/Sites/mywebsite
git config -f .gitmodules submodule.themes/blowfish.shallow true
```

> This command just added `shallow = true` to the `themes/blowfish` submodule in the `.gitmodules` file.

When in need to clone the repository into another computer, you have to keep in mind that, when cloning a repository that contains submodules, you have to initialise them explicitly.

```bash
GIT_SSH_COMMAND="ssh -i ~/.ssh/your_key -o IdentitiesOnly=yes" \
  git clone --recurse-submodules \
  git@github.com:<username>/mywebsite.git
```

> If you only have one SSH key, you can skip the `GIT_SSH_COMMAND` option.

Now, run the following commands inside the new repository directory so that you can start working with it immediately:

```bash
git config core.sshCommand "ssh -i ~/.ssh/your_key -o IdentitiesOnly=yes"
git config user.name "Your Name"
git config user.email "your.email@domain.com"
```

Finally, we will create a `.gitignore` file to exclude certain files from the repository automatically.

```gitignore
# Hugo
.DS_Store
.hugo_build.lock
*.test
imports.*
dist/
public/
```

We are now ready to commit our first changes to the repository.

```bash
git add .
git commit -a -m "Added Blowfish theme and gitignore file"
```

As you advance through this tutorial, do not forget to commit your changes to your local repository every time you think that you have a new, stable version. For that, use the following commands:

| Command                 | Description                               |
|-------------------------|-------------------------------------------|
| git add .               | Add all changes to the staging area       |
| git commit -m "Message" | Commit the changes with a message         |
| git push                | Push the changes to the remote repository |

Throughout the article I will be ommitting the `git push` command, as I will be assuming that you will be pushing your changes to the remote repository at the end of each section. However, you can push your changes at any time.

## Configure Blowfish

Delete the `hugo.toml` file from the root folder of the website that was generated by Hugo, then copy the `*.toml` files from the `themes/blowfish/config/_default/` sub-directory into the `config/_default/` folder. This will ensure that you have all the correct configuration files so that you can start customising them.

```bash
cd ~/Sites/mywebsite
rm hugo.toml
mkdir --parents config/_default
cp --archive themes/blowfish/config/_default/*.toml config/_default/
```

Before creating any content we will go through all the configuration files and set a few directives.

### Site configuration

First, edit the `hugo.toml` file to set the theme, the language and the base URL of the site. The `languageCode` should be set to the main language that you will be using to author your content.

```toml
# config/_default/hugo.toml

theme = "blowfish"
baseURL = "https://mywebsite.com/"
languageCode = "en"
```

### Languages

Next we will configure the language settings. Blowfish supports multi-lingual but, for now, we will configure the main language only.

Locate the `languages.en.toml` file in the `config/_default/` configuration folder. If you just configured a different language in the `hugo.toml`, rename the file to match it. For example, for Catalan, you would have used `languageCode = "ca"` and would rename the file to `languages.ca.toml`.

```toml
title = "The title of my website"

[params]
  logo = "img/logo.png"

[params.author]
  name = "My Name"
  image = "img/author.jpg"
  headline = "This text will appear beneath the author profile in the home page"
  bio = "This text will appear next to the author icon in each article"
  links = [
    { email = "mailto:username@mywebsite.com" },
    { github = "https://github.com/<username>/" },
  ]
```

The image in the `logo` attribute will be shown left of the site name, in the header.

The `[author]` configuration determines how the author information is displayed on the website. The image should be placed in the `assets/` folder. Links will be displayed in the order they are listed.

This is a quick overview of the current structure of folders.

```tree
.
├── assets
│   └── img
│       └── author.jpg
├── config
│   └── _default
│       ├── hugo.toml
│       ├── languages.en.toml
│       ├── menus.en.toml
│       └── params.toml
├── content
└── themes
    └── blowfish
```

### Colour scheme

Blowfish includes some colour schemes out of the box. To change the scheme, simply set the `colorScheme` theme parameter to any of the [valid options](https://blowfish.page/docs/getting-started/#colour-schemes) in your `config/_default/params.toml` configuration file.

```toml
colorScheme = "avocado"
defaultAppearance = "dark"
autoSwitchAppearance = true
```

Notice that we switched the default appearance from `light` to `dark`. However, setting the `autoSwitchAppearance` parametre to `true` renders this option useless, as Blowfish will use the visitor's operating system configuration.

Moreover, going back to the `config/_default/languages.en.toml` configuration file, we have the option to set a complimentary logo for the secondary appearance, which would be `light` in our case:

```toml
[params]
  logo = "img/logo.png"
  secondaryLogo = "img/secondary-logo.png"
```

## Privacy settings

If, like me, you do not plan on integrating your Hugo website with external services, you can take advantage of the privacy configuration options in the `hugo.toml` file to disable all services.

```toml
[privacy]
  [privacy.disqus]
    disable = true
  [privacy.googleAnalytics]
    disable = true
  [privacy.instagram]
    disable = true
  [privacy.twitter]
    disable = true
  [privacy.vimeo]
    disable = true
  [privacy.youtube]
    disable = true
```

Optionally, commit these changes to the repository:

```bash
git add .
git commit -m "Configured the site, language, colour and privacy settings"
```

## Organising content

In Hugo, your content should be organized in a manner that reflects the rendered website. All content is placed within the `content` folder. While Hugo supports content nested at any level, the top levels (i.e., `content/<directory>`) are special and are considered the [content type](https://gohugo.io/content-management/types/) used to determine layouts.

Hugo defaults to using _posts_, _tags_ and _categories_ out of the box. Hence, Blowfish is configured to use _posts_ by default. You can notice this default behaviour by checking the value of the `showMoreLinkDest` option in the `config/_default/params.toml` configuration file.

However, Blowfish does not force you to use any particular content type. You may want to use _pages_ for a static site, _posts_ for a blog, or _projects_ for a portfolio. Whatever option you end up with, it is important to have a good understanding of [how Hugo expects content to be organised](https://gohugo.io/content-management/organization/), as the theme is designed to take full advantage of [Hugo page bundles](https://gohugo.io/content-management/page-bundles/).

Moreover, a taxonomy is a categorization that can be used to classify content in a logical manner so users can easily navigate the site and understand its purpose. A term is a key within the taxonomy. And a value is a piece of content assigned to a term. Visually, this may look like different sections and pages within a website, or categories within a blog.

By default, Blowfish defines the following taxonomies in the `config/_default/hugo.toml` configuration file:

```toml
[taxonomies]
  tag = "tags"
  category = "categories"
  author = "authors"
  series = "series"
```

> Note: There is a convention to use `singular = "plural"`.

Categories organize your site and allow readers to find the information they want. They are high-level topics that make it easy for people to understand what your blog is about and navigate to the content that interests them. The categories provide structure to your site by organizing individual posts and sub-topics under several main topics. 

On the other hand, a tag is an indicator of what a particular post is about. Each tag is one to three words that sort your post into a particular archive. Tags should not have the same names as categories to prevent overlap.

Therefore, we just found an easy way to get started using Hugo for our blog:

* All articles will be of a single content type, _posts_.
* Each article will belong to a single category, e.g., `frameworks`, `virtualisation`, `automation` and `monitoring`, to get started with.
* Each article will have a number of tags, e.g. `hugo`, `proxmox`, `ansible`, `prometheus`, and so on.

When taxonomies are used, Hugo will automatically create both a page listing all the taxonomy's terms and individual pages with lists of content associated with each term. With the default values, Hugo will create:

* A single page at `mywebsite.com/categories/` that lists all the terms within the taxonomy.
* Individual taxonomy list pages (e.g., `mywebsite.com/categories/some-term/`) for each of the terms that shows a listing of all pages marked as part of that taxonomy.

> Note: `mywebsite.com/index.xml` is essentially your RSS feed, you can target any section of your site by changing the URL. So for instance `mywebsite.com/posts/index.xml` is an RSS feed for your posts folder.

## Creating content

So, to get started we will create the subdirectory `content/posts/` for our _posts_ content type and we will create a few markdown files inside the `content/` and the `content/posts/` folders. 

All of them will include [front matter](https://gohugo.io/content-management/front-matter/) at the top, as this is how we add metadata to our content. Hugo accepts YAML, TOML and JSON for the front matter. Although TOML used to be the default format, YAML has become the de facto standard and, therefore, we will use it was well.

The number of [available fields](https://gohugo.io/content-management/front-matter/#fields) is extensive, but we will get started with the `title`, `description` and `date` fields for all our files and, in case of a post, we will include the `summary`, `categories` and `tags` fields as well.

```yaml
# Example of content/_index.md
---
title: "The title of the home page"
description: "The description of the home page."
date: "2024-07-18"
---

Additional content displayed in the home page.
```

```yaml
# Example of content/about.md
---
title: "The title of the about me page"
description: "The description of the about me page."
date: "2024-07-18"
---

This is the content of the about me page.
```

```yaml
# Example of content/posts/_index.md
---
title: "Blog posts"
description: "List of articles, grouped by year."
---

List of articles in the blog, grouped by year.
```

```yaml
# Example of content/posts/ansible-proxmox-lxc.md
---
title: "Ansible playbook to provision LXC in Proxmox"
description: "This text will appear in the description meta tag."
summary: "This text will be displayed when the article appears in a list."
date: "2024-08-22"
categories: ["automation"]
tags: ["proxmox", "ansible", "pve"]
slug: "ansible-proxmox-lxc"
---

This article explains how to create an Ansible playbook that leverages the `proxmoxer` module to provision a LinuX Container in our Proxmox Virtual Environment.
```

Taking these three examples as reference, we can create the rest of article files and have a content tree that looks like this.

```tree
.
└── content
    ├── _index.md                     → /
    ├── about.md                      → /about/
    ├── posts
    │   ├── _index.md                 → /posts/
    │   ├── ansible-proxmox-lxc.md    → /posts/ansible-proxmox-lxc/
    │   ├── hugo-installation.md      → /posts/hugo-installation/
    │   ├── hugo-key-concepts.md      → /posts/hugo-key-concepts/
    │   ├── pbs-introduction.md       → /posts/pbs-introduction/
    │   ├── pve-design.md             → /posts/pve-design/
    │   ├── pve-introduction.md       → /posts/pve-introduction/
    │   ├── pve-os-configuration.md   → /posts/pve-os-configuration/
    │   └── pve-os-installation.md    → /posts/pve-os-installation/
    └── privacy.md                    → /privacy/
```

Regarding the `content/_index.md` and `content/posts/_index.md` files, `_index.md` has a special role in Hugo. It allows you to add front matter and content to `home`, `section`, `taxonomy`, and `term` pages. You can create one `_index.md` for your home page and one in each of your content sections, taxonomies, and terms.

Regarding the `content/about.md` file, that is just a standalone page.

You can now start the server inside the root directory of the website. The web server makes itself available at the `http://localhost:1313/` address by default.

```bash
hugo server --buildDrafts
```

The `buildDrafts` option passed to the server will make it include articles marked with `draft: true` in their front matter, which is a very useful tool when you are writing a new article but you are not finished yet.


Let's suppose that taxonomies were use like this.

| Article              | Category       | Tags                  |
|----------------------|----------------|-----------------------|
| ansible-proxmox-lxc  | automation     | ansible, proxmox, pve |
| hugo-installation    | frameworks     | hugo, blowfish        |
| hugo-key-concepts    | frameworks     | hugo                  |
| pbs-introduction     | infrastructure | proxmox, pbs          |
| pve-introduction     | virtualisation | proxmox, pve          |
| pve-design           | virtualisation | proxmox, pve          |
| pve-os-configuration | virtualisation | proxmox, pve          |
| pve-os-installation  | virtualisation | proxmox, pve          |

Hugo would generate the following additional URLs.

* `http://localhost:1313/categories/automation`
* `http://localhost:1313/categories/frameworks`
* `http://localhost:1313/categories/infrastructure`
* `http://localhost:1313/categories/virtualisation`

Each of these URLs would list the articles that have been asigned to the corresponding category. Furthermore, Hugo would also generate the following additional URLs.

* `http://localhost:1313/tags/ansible`
* `http://localhost:1313/tags/blowfish`
* `http://localhost:1313/tags/hugo`
* `http://localhost:1313/tags/proxmox`
* `http://localhost:1313/tags/pbs`
* `http://localhost:1313/tags/pve`

Each of these URLs would list the articles that have been associated with the corresponding tag.

Moreover, all of the above URLs include both an `index.html` and `index.xml`, where the latter acts as a RSS feed for the section.

Similarly to the home page example given before in this section, you can customise the introductory text and the metadata of any taxonomy or term.

```yaml
# Example of content/categories/_index.md
---
title: "Categories"
description: "The list of categories this blog is split into."
date: "2024-07-18"
---

These are the available categories in this blog. Click on any of them to see the list of articles, its amount being displayed as a counter in each card.
```

```yaml
# Example of content/categories/frameworks/_index.md
---
title: "Frameworks"
description: "The list of articles in the frameworks category."
date: "2024-07-18"
---

This is the frameworks category, which covers all articles related to software development frameworks, such as Hugo or Django.
```

```yaml
# Example of content/categories/virtualisation/_index.md
---
title: "Virtualisation"
description: "The list of articles in the virtualisation category."
date: "2024-07-18"
---

This is the virtualisation category term, which covers all articles related to technologies that allow dividing of physical computing resources into a series of virtual machines, operating systems, processes or containers, mainly via the Proxmox Virtual Environment.
---
```

Most of the changes made to the files in your project will be automatically available in your browser, as Hugo will detect them, recompile the necessary files and reload the page for you. However, some changes will not, so they will require you to stop the server and launch it again.

## Menus

The Blowfish theme includes two menus. The `main` menu in the header and the `footer` menu appears at the bottom of the page. Both menus are configured in the `menus.en.toml` file. Similarly to the languages config file, if you configured a different language in the `hugo.toml`, rename the file to match it.

The `name` parametre specifies the text that is used in the menu link. Optionally, a `title` can be provided which will be used in the corresponding attribute of the HTML tag.

The `pageRef` parametre allows you to easily reference Hugo content pages and taxonomies, whereas the `url` parametre is used to link to external URLs.

The `pre` parametre allows you to choose an icon from [Blowfish's icon set](https://blowfish.page/samples/icons/) to be displayed next to the name of the menu entry.

By default the menu is ordered alphabetically. This can be overridden by using the `weight` parametre. The menu will then be ordered by weight from lowest to highest.

Again, by default Blowfish comes configured to use the _posts_ content type as well as the `categories` and `tags` taxonomies so, in order to match our current conent, we will just need to uncomment a few entries and add a few more in the `config/_default/menus.en.toml`.

```toml
[[main]]
  name = "Blog"
  title = "The list of articles in this blog"
  pageRef = "posts"
  weight = 10

[[main]]
  name = "Categories"
  pageRef = "categories"
  weight = 20

[[main]]
  name = "Tags"
  pageRef = "tags"
  weight = 30

[[main]]
  name = "About"
  pageRef = "about"
  weight = 40

[[main]]
  name = "About"
  title = "About me"
  pageRef = "about"
  weight = 40

[[main]]
  identifier = "Github"
  pre = "github"
  url = "https://github.com/username"
  weight = 50

[[main]]
  identifier = "Email"
  pre = "email"
  url = "mailto:username@mywebsite.com"
  weight = 70

[[footer]]
  name = "Privacy policy"
  pageRef = "privacy"
  weight = 10
```

## Thumbnails

Blowfish offers an easy way to add visual support to your posts in the form of thumbnails, which will also be used for [oEmbed](https://oembed.com/) cards across social platforms. In order to take advantage of this feature, you need to change it from a single Markdown file into a folder, i.e., a leaf bundle.

To do so, first create a directory with the same name of the article, then create a `index.md` file inside, with the contents of the article. Finally, place an image file named `featured.webp` (JPG, PNG, SVG and WebP formats are supported).

The configuration file `config/_default/params.toml` allows lists of articles to be rendered as rows or a gallery of cards via the `cardView` parametre. The size of the canvas will determine how the image will be rendered. Height will range from 180 to 320 pixels, whereas width will range between 260 and ~580 px.

Images with an aspect ratio of 3:2 (e.g., 600x400 px) should fit in nicely. An online tool such as [RedKetchup's Image Resizer](https://redketchup.io/image-resizer) will be of help.

The end result will be similar to this.

```tree
.
└── content
    ├── _index.md                     → /
    ├── about.md                      → /about/
    ├── posts
    │   ├── ansible-proxmox-lxc
    │   │   ├── index.md              → /posts/ansible-proxmox-lxc/
    │   │   └── featured.webp
    │   ├── hugo-installation
    │   │   ├── index.md              → /posts/hugo-installation/
    │   │   └── featured.webp
    │   ├── hugo-key-concepts
    │   │   ├── index.md              → /posts/hugo-key-concepts/
    │   │   └── featured.webp
    │   ├── pbs-introduction
    │   │   ├── index.md              → /posts/pbs-introduction/
    │   │   └── featured.webp
    │   ├── pve-design
    │   │   ├── index.md              → /posts/pve-design/
    │   │   └── featured.webp
    │   ├── pve-introduction
    │   │   ├── index.md              → /posts/pve-introduction/
    │   │   └── featured.webp
    │   ├── pve-os-configuration
    │   │   ├── index.md              → /posts/pve-os-configuration/
    │   │   └── featured.webp
    │   └── pve-os-installation
    │       ├── index.md              → /posts/pve-os-installation/
    │       └── featured.webp
    └── privacy.md                    → /privacy/
```

> Note that the file with the article content, `index.md`, does not beging with an underscore.

## Favicons

In order to override the default set of blank icons provided by the Blowfish theme, the favicon assets need to be placed directly under the `static/` folder, named as per the listing below.

```tree
.
└── static
    ├─ android-chrome-192x192.png
    ├─ android-chrome-512x512.png
    ├─ apple-touch-icon.png
    ├─ favicon-16x16.png
    ├─ favicon-32x32.png
    ├─ favicon.ico
    └─ site.webmanifest
```

The recommended way to obtain these is to generate them using a third-party provider such as [RedKetchup's Favicon Generator](https://redketchup.io/favicon-generator) or [favicon.io's Favicon Generator](https://favicon.io/favicon-converter/), which will produce exactly these filenames. Just upload your image (at least 512x512 pixels) and download the Zip archive with all the necessary files, which you can unarchive directly into the `static/` folder of your website.

## Finetuning the layout

Some final, optional touches to the way articles, lists of articles and taxonomy terms are displayed in your blog. All of these parametres are available in the `config/_default/params.toml` configuration file.

### Articles

The [list of parametres applying to article pages](https://blowfish.page/docs/configuration/#article) is very extensive, but here you are some of the most relevant.

* `showDateUpdated` allows the date of the last update to be displayed in the article header. This is useful if you are updating articles frequently.
* `enableCodeCopy` decides whether copy-to-clipboard buttons are enabled for `<code>` blocks. Useful if you are displaying programming code.
* `showBreadcrumbs` allows breadcrumbs to be displayed in the article header.
* `showTableOfContents` shows the table of contents is displayed on articles, by default in a column on the right.
* `showTaxonomies` allows taxonomies related to an article to be displayed beneath its title.
* `showZenMode` activates the Zen Mode reading feature for articles, which takes out the right column with the table of contents so the content of the article takes all the space.

```toml
enableCodeCopy = true

[article]
  showDateUpdated = true
  showBreadcrumbs = true
  showTableOfContents = true
  # showRelatedContent = true
  # relatedContentLimit = 3
  showTaxonomies = true
  showZenMode = true
```

When you have added enough content to your website, you may want to list [related articles](https://gohugo.io/content-management/related/) at the bottom of your posts. The default configuration of Blowfish requires you to just comment out the following parametres:

* `showRelatedContent` will display related content for each post.
* `relatedContentLimit` will limit the number of related articles to display.

Hugo allows finetuning [the way related content is indexed](https://gohugo.io/content-management/related/#configure-related-content), both on the global and language levels if needed. The configuration options are available in the `[related]` section of the `config/_default/hugo.toml` file. Playing with these paramtres will change how Hugo decides which articles will be displayed in the _Related_ section.

```toml
[related]
  threshold = 0
  toLower = false

    [[related.indices]]
        name = "tags"
        weight = 100

    [[related.indices]]
        name = "categories"
        weight = 100

    [[related.indices]]
        name = "series"
        weight = 50

    [[related.indices]]
        name = "authors"
        weight = 20

    [[related.indices]]
        name = "date"
        weight = 10

    [[related.indices]]
      applyFilter = false
      name = 'fragmentrefs'
      type = 'fragments'
      weight = 10
```

The above configuration, being the default taken from Blowfish, is instructing Hugo to use tags and categories that articles may have in common as they main criteria, then the series articles may belong to and, finally, shared author and same date. The last block is instructing Hugo to index the metadata of the articles to calculate related content.

### Lists of articles

The [list of parametres applying to article pages](https://blowfish.page/docs/configuration/#list) is fairly extensive. These are just a noteworthy few.

* `showSummary` includes the summary in each listed article. Summaries, when not included in the front matter of each article, are generated using the `summaryLength` in the `config/_default/hugo.toml` configuration file.
* `showCards` makes each article to be displayed as a card instead of as simple inline text.
* `cardView` displays lists as a gallery of cards.
* `constrainItemsWidth` limits item width to the width of the summary to increase readability when no feature images are available.

```toml
[list]
  showSummary = true
  showCards = true
  cardView = true
  constrainItemsWidth = false
```

### Taxonomies    

Regarding [taxonomies](https://blowfish.page/docs/configuration/#taxonomy) and [taxonomy terms](https://blowfish.page/docs/configuration/#term), a relevant one so that the style of the blog is coherent:

* `cardView` displays lists as a gallery of cards.

These are the 

```toml
[taxonomy]
  cardView = true

[term]
  cardView = false
```

The `taxonomy` section refers to the `/tags/` and `/categories/` in our example website, whereas the `term` section refers to each term page of each taxonomy, e.g., `/tags/proxmox/` or `/categories/frameworks/`.

## Configuring the home page

Blowfish provides a variety of [layouts for your home page](https://blowfish.page/docs/homepage-layout/). As with articles, lists, taxonomies and terms, you can find [a number parametres](https://blowfish.page/docs/configuration/#homepage) to finetune the layout of your choice in the `config/_default/params.toml` configuration file.

```toml
# We only want entries of content type `posts` to be listed
# in the recent section of the homepage.
mainSections = ["posts"]

highlightCurrentMenuArea = true

[homepage]
  layout = "profile"
  showRecent = true
  showRecentItems = 6
  showMoreLink = true
  showMoreLinkDest = "/posts"
  cardView = true
```

The above configuraration will use the default `profile` layout, highlight the current option in the menu, show the six most recent articles (sorted by the date in the metadata) using the card view and display and show `Show More` button at the bottom of the list of recent articles, linking to `/posts`.

If you would like to use a backoground image, you need to change the `layout` parametre and add an image to your `assets/` folder. You will notice that Blowfish will adapt the image to the colour scheme defined in the `config/_default/params.toml` configuration file and the selected layout for the home page.

```toml
[homepage]
  layout = "background"
  homepageImage = "img/background.webp"
```

## Series

If you would like to split very long subjects into different posts, i.e., to group articles together, [Blowfish series](https://blowfish.page/docs/series/) is the feature you are looking for.

Assigning articles to a series will provide a quick way to navigate amongst them at the top and bottom of each article. Blowfish comes preconfigured with a `series` taxonomy in the `config/_default/hugo.toml` configuration, so all we need to do is to mark articles using the `series` and `series_order` parametres in the front matter.

Taking our four articles in the `virtualisation` category, we would edit their front matter to look something like this.

```yaml
# content/posts/pve-introduction/index.md
---
title: "Your Proxmox VE 7 cluster at Hetzner"
date: 2024-07-30
description: "Install and configure a multi-node Proxmox Virtual Environment cluster using dedicated servers at Hetzner."
summary: "Plan, install and configure a Proxmox VE cluster using dedicated servers at Hetzner"
categories: ["virtualisation"]
tags: ["proxmox", "pve"]
slug: "pve-introduction"
series: ["PVE"]
series_order: 1
---
```

```yaml
# content/posts/pve-design/index.md
---
title: "Design considerations"
date: "2024-07-30"
description: "Giving our Proxmox cluster some thought before getting started."
summary: "Design the network configuration of your cluster before you get started."
categories: ["virtualisation"]
tags: ["proxmox", "pve"]
slug: "pve-design"
series: ["PVE"]
series_order: 2
---
```

You can choose whether the series section is collapsed or expanded by default both at the global level, via the `seriesOpened` in the `config/_default/params.toml` configuration file, and at the article level via the `seriesOpened` parametre in the front-matter of each article. The default behaviour is for the section to be collapsed.

The values assigned to the `series_order` parametre do not need to be consecutive, but they are supposed to be because of the way Blowfish renders the section.

## Improving content organisation using sections

By now you must have realised that we have been somewhat prefixing the folder names of the articles to avoid conflicts and also to make them easier to notice. Eventually, though, our `content/posts/` folder will be clutered with many folders and files.

> Remember that Hugo assumes that the same structure that works to organize your source content is used to organize the rendered site.

A [section](https://gohugo.io/content-management/sections/) is a top-level content directory or any content directory with an `_index.md` file, also known as a branch bundle. Analogous to a physical branch, a branch bundle may have descendants including leaf bundles and other branch bundles.

> A content type is also considered a section, although it does not have an `_index.md` file inside it, because it is a top-level content directory.

A folder inside `content/posts/` with an `_index.md` file in it, i.e., a section, becomes part of the path in the URL, has logical ancestors and descendants, which would help rendering the content in a hierarchical manner and a list page, correponding with their respective `_index.md` files, which will list the articles in that section.

Posts inside a section will not be included in top-level lists (e.g., `/posts/`) but, instead, the section will. They will still appear in blocks of recent or related posts, though. Moreover, the list of posts in a section (e.g., `content/posts/hugo/`) will only include first level descendants.

A folder inside `content/posts/` (e.g., `content/posts/hugo/`) without an `_index.md` file in it, i.e., a non-section, becomes part of the path in the URL but does not have a list page.

Therefore, non-sections will return a `404 Page Not Found` error, although they will not be listed anywhere in the generated site. Their only purpose is to help organise the content on disk, with that structure being part of the path.

Expanding on our example, we could restructure the content in a more hierarchical manner using non-sections. We would keep using one single content type, i.e., _posts_, and keep taxonomies without changes.

```tree
.
└── content
    ├── _index.md                     → /
    ├── about.md                      → /about/
    ├── posts
    │   ├── _index.md                 → /posts/
    │   ├── ansible                   → /posts/ansible/
    │   │   └── lxc-provisioning
    │   │       ├── index.md          → /posts/ansible/lxc-provisioning/
    │   │       └── featured.webp
    │   ├── hugo
    │   │   ├── installation
    │   │   │   ├── index.md          → /posts/hugo/installation/
    │   │   │   └── featured.webp
    │   │   └── key-concepts
    │   │       ├── index.md          → /posts/hugo/key-concepts/
    │   │       └── featured.webp
    │   └── proxmox
    │       ├── pbs
    │       │   ├── index.md          → /posts/proxmox/pbs/
    │       │   └── featured.webp
    │       └── pve
    │           ├── _index.md         → /posts/proxmox/pve/
    │           ├── featured.md
    │           ├── design
    │           │   ├── index.md      → /posts/pve/design/
    │           │   └── featured.webp
    │           ├── introduction
    │           │   ├── index.md      → /posts/pve/introduction/
    │           │   └── featured.webp
    │           ├── os-configuration
    │           │   ├── index.md      → /posts/pve/os-configuration/
    │           │   └── featured.webp
    │           └── os-installation
    │               ├── index.md      → /posts/pve/os-installation/
    │               └── featured.webp
    └── privacy.md                    → /privacy/
```

Note how sections and non-sections are being used. `content/posts/ansible/`, `content/posts/hugo/` and `content/posts/proxmox/` are non-sections, used to organise the content in subdirectories only, whereas `content/posts/proxmox/pve/` is a section, used to mask all the posts beneath it by grouping them into a single entry (as opposed to having them all show separately).

```yaml
# Example of content/posts/proxmox/pve/_index.md
---
title: "Your Proxmox VE cluster"
description: "Install and configure a multi-node Proxmox Virtual Environment cluster."
summary: "Plan, install and configure a Proxmox VE cluster using dedicated servers."
categories: ["virtualisation"]
tags: ["proxmox", "pve"]
---

Install and configure a multi-node Proxmox Virtual Environment cluster using dedicated servers at Hetzner.
```

Should you want to customise the path of each article, you can use [permalink tokens](https://gohugo.io/content-management/urls/#tokens) in the `url` parametre of the front matter of the `_index.md` file of the section, or in the site configuration file.

```toml
# Example of config/_default/hugo.toml

[permalinks]
  [permalink.posts]
   posts = "/:sections/:slugorfilename"
```

## Emphasising categories

If you would like to bring up the relevance of categories, to boost your SEO and enhance site nativation by establishing a clear hierarchy, you could turn them into top-level sections, which would render them unnecessary in the front matter of the articles.

```tree
.
└── content
    ├── _index.md
    ├── about.md
    ├── automation
    │   ├── _index.md
    │   ├── lxc
    │   └── proxmox
    ├── frameworks
    │   ├── _index.md
    │   └── hugo
    ├── infrastructure
    │   ├── _index.md
    │   ├── databases
    │   ├── monitoring
    │   └── pbs
    ├── virtualisation
    │   ├── _index.md
    │   └── pve
    └── privacy.md
```

This would require adapting the menu options in the `config/_default/menus.en.toml` file, maybe adding a new _Articles_ menu entry with the sections as submenu options.

There are infinite ways to organise the content. As with everything in life, the best way to achieve a good result will be through observation, planning and experimentation.

## Publishing

As you finish writing articles, or maybe also while you are writing them, you want to keep your changes committed to the repository. This will allow you to keep track of your changes and revert them if necessary.

```bash
git add .
git commit -m "Added a new article about Hugo and Blowfish"
```

Once you are happy with the content of your blog, you will want to publish it. There are two ways to do so:

* Automatically, by connecting your repository to a hosting provider that supports Hugo.
* Manually, by generating the static files and uploading them to a web server.

In the second case, you will have to use the `hugo` command:

```bash
cd ~/Sites/mywebsite
hugo --minify --cleanDestinationDir
```

The resulting files will be placed in the `public/` directory.

The `--minify` option will minify the HTML, CSS and JavaScript files, which will reduce the size of the files and improve the loading time of your website.

The `--cleanDestinationDir` option will remove any files in the `public/` directory that are not present in the source files, which is useful to keep the generated site clean.

## Cloudflare Pages

There are certain prerequisites that you need to meet before you can deploy your Hugo site to Cloudflare Pages, namely:

1. You registered a domain name with some domain registrar.
2. You registered an account at Cloudflare.
3. You added your domain to Cloudflare.
4. You have configured your domain name to use Cloudflare's nameservers.

Cloudflare calls this configuration a [full setup](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/). You do not need to register your domain with Cloudflare to use Cloudflare Pages, but you do need to add your domain to Cloudflare and configure it to use Cloudflare's nameservers.

Once you have completed the full setup, you can easily deploy your Hugo site by following these steps:

1. Log into your [Cloudflare dashboard](https://dash.cloudflare.com/) and select your account (should you have more than one).
2. In account home, select `Compute (Workers) > Workers & Pages`.
3. Select the `Pages` tab.
4. Click on the `Get started` button on the `Import an existing Git repository` card.
5. Select the `Github` tab and click on the `Connect GitHub` button.
6. Select your Github account where you have your Hugo site repository.
7. Select the `Only select repositories` and choose the repository from the dropdown list.
8. Click on the `Install & Authorize` button.
9. Back at Cloudflare, select the repository you just connected and click the `Begin setup` button.
10. In the `Set up builds and deployments` step, fill in the following fields and click `Continue`:

| Field name             | Value       | Notes                                                           |
|------------------------|-------------|-----------------------------------------------------------------|
| Project name           | `mywebsite` | The name of your project                                        |
| Production branch      | `main`      | Default value should do                                         |
| Build command          | `hugo`      | Optionally, add `--minify --cleanDestinationDir` to the command |
| Build output directory | `public`    |                                                                 |

11. Clodflare Pages will start the building and deploying process. The operation should end successfully in a few seconds, as you already have a working Hugo site in your repository.
12. Click on the `Add custom domain` card to add your domain name to the project[^1]. In the next page, click the `Set up a custom domain` button and enter your domain name, e.g., `mywebsite.com`. Click on the `Continue` button.
13. Click on the `Activate domain` button. Cloudflare will change the DNS records and issue the SSL certificate.
14. In the next page you will see Cloudflare verifying the changes and waiting for the DNS propagation to complete. Once complete, you will see the `Verifying` status change to `Active`. You may now visit your website at `https://mywebsite.com/`. 

At the Cloudflare Workers & Pages dashboard you will see four tabs:

* **Deployments**: Shows the list of deployments made to your project. You can view the log of each deployment by clicking on the `View details` link.
* **Metrics**: Shows the metrics of your project, such as the number of requests. It lets you enable [Web Analytics](https://developers.cloudflare.com/analytics/web-analytics/), should you wish to do so.
* **Custom domains**: Shows the list of domains associated with your project. We were just there.
* **Settings**: Allows you to change the settings of your project, such as the build command and, more importantly, use a specific version of Hugo by setting the `HUGO_VERSION` environment variable. This is useful if you want to use a specific version of Hugo that is not the latest one.


[^1]: Preview end result by visiting your project at `mywebsite.pages.dev`.

New commits will trigger Cloudflare to automatically build and deploy your changes.