/*
 * This file is part of the xPack project (http://xpack.github.io).
 * Copyright (c) 2024 Liviu Ionescu. All rights reserved.
 *
 * Permission to use, copy, modify, and/or distribute this software
 * for any purpose is hereby granted, under the terms of the MIT license.
 *
 * If a copy of the license was not distributed with this file, it can
 * be obtained from https://opensource.org/licenses/MIT/.
 */

import Link from '@docusaurus/Link';

import type {FeatureItem} from './FeatureItem'

export const FeatureList: FeatureItem[] = [
  {
    title: 'Cross-platform',
    Svg: require('@site/static/img/mosaic.svg').default,
    description: (
      <>
        The <b>xPack Build Box</b> is designed to automate the building and testing of <b>large-scale projects</b>, with <b>many dependencies</b>, on both <b>GNU/Linux</b> and <b>macOS</b>.
      </>
    ),
  },
  {
    title: 'Easy to Use & Reproducible',
    Svg: require('@site/static/img/check-badge.svg').default,
    description: (
      <>
        XBB ensures a consistent environment with <b>identical versions</b> of dependencies, irrespective of the distribution or version of the development platform.
      </>
    ),
  },
  {
    title: 'Part of the xPack ecosystem',
    Svg: require('@site/static/img/globe.svg').default,
    description: (
      <>
        The dependencies are not hard-coded in the environment but are installed as <b>binary dependencies</b> with <b><Link to="https://xpack.github.io/xpm/">xpm</Link></b>. This approach offers significant flexibility and extensibility.
      </>
    ),
  },
];
