// DO NOT EDIT!
// Automatically generated from docusaurus-template-liquid/templates/docusaurus.

import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';
import {userSidebarCategory} from "./sidebar-user";

/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */
const sidebars: SidebarsConfig = {

  
  docsSidebar: [
    {
      type: 'doc',
      id: 'getting-started/index',
      label: 'Getting Started'
    },
    userSidebarCategory,
    {
      type: 'doc',
      id: 'maintainer/index',
      label: 'Maintainer\'s Guide'
    },
    {
      type: 'doc',
      id: 'faq/index',
      label: 'FAQ'
    },
    {
      type: 'doc',
      id: 'support/index',
      label: 'Help Centre'
    },
    {
      type: 'doc',
      id: 'releases/index',
      label: 'Releases'
    },
    {
      type: 'category',
      label: 'Project',
      link: {
        type: 'doc',
        id: 'project/about/index',
      },
      collapsed: false,
      items: [
        {
          type: 'doc',
          id: 'project/about/index',
          label: 'About'
        },
        {
          type: 'doc',
          id: 'project/history/index',
          label: 'History'
        },
        {
          type: 'link',
          label: 'License',
          href: 'https://opensource.org/license/MIT',
        },
      ]
    },
  ],
  
  
};

export default sidebars;
