const CONFIG = {
  macros: [
    {
      category: 'Entertainment',
      name: 'YouTube',
      triggers: [
        'y',
        'yt',
        'youtube',
      ],
      key: 'KeyY',
      icon: 'youtube',
      url: 'https://youtube.com',
      normalisedURL: 'youtube.com',
      commands: {
        go: {
          template: 'https://youtu.be/{$}',
          description: 'go to video'
        },
        search: {
          template: '{@}/results?search_query={$}'
        }
      },
      bgColor: {
        type: 'solid',
        color: '#f30002'
      },
      textColor: '#e8e8e8',
      pinned: true
    },
    {
      category: 'Social',
      name: 'Reddit',
      triggers: [
        'r',
        'rd',
        'reddit',
      ],
      key: 'KeyR',
      icon: 'reddit',
      url: 'https://reddit.com',
      normalisedURL: 'reddit.com',
      commands: {
        go: {
          template: '{@}/r/{$}',
          description: 'go to subreddit'
        },
        search: {
          template: '{@}/search?q={$}'
        }
      },
      bgColor: {
        type: 'gradient',
        gradientType: 'linear',
        colors: ['#f07e23', '#f74300'],
        stops: [0, 100]
      },
      textColor: '#e8e8e8',
      pinned: true
    },
    {
      category: 'Social',
      name: 'AniList',
      triggers: [
        'a',
        'an',
        'anilist',
      ],
      key: 'KeyA',
      icon: 'anilist',
      url: 'https://anilist.co',
      normalisedURL: 'anilist.co',
      bgColor: {
        type: 'solid',
        color: '#1e2030',
      },
      textColor: '#e8e8e8',
      pinned: false
    },
    {
      category: 'Social',
      name: 'osu',
      triggers: [
        'o',
        'osu',
      ],
      key: 'KeyO',
      icon: 'osu',
      url: 'https://osu.ppy.sh',
      normalisedURL: 'osu.ppy.sh',
      bgColor: {
        type: 'solid',
        color: '#e7669f',
      },
      textColor: '#e8e8e8',
      pinned: false
    },    {
      category: 'Programming',
      name: 'GitHub',
      icon: 'github',
      url: 'https://github.com',
      normalisedURL: 'github.com',
      triggers: [
        'g',
        'git',
        'github'
      ],
      key: 'KeyG',
      commands: {
        go: {
          template: '{@}/{$}',
          description: 'go to user'
        },
        search: {
          template: '{@}/search?q={$}'
        }
      },
      bgColor: {
        type: 'solid',
        color: '#171515'
      },
      textColor: '#e8e8e8',
      pinned: true
    },
    {
      category: 'Social',
      name: 'Twitch',
      icon: 'twitch',
      url: 'https://twitch.tv',
      normalisedURL: 'twitch.tv',
      triggers: [
        'tw',
        'twitch',
      ],
      key : 'KeyT',
      commands: {
        search: {
          template: '{@}/search?term={$}'
        },
        go: {
          template: '{@}/{$}'
        }
      },
      bgColor: {
        type: 'solid',
        color: '#8c44f7'
      },
      textColor: '#e8e8e8',
      pinned: true
    },
    {
      category: 'Search',
      name: 'DuckDuckGo',
      triggers: [
        'dd',
        'ddg',
        'duck',
        'duckduck',
        'duckduckgo'
      ],
      url: 'https://duckduckgo.com',
      normalisedURL: 'duckduckgo.com',
      commands: {
        search: {
          template: '{@}/?q={$}'
        }
      },
      bgColor: {
        type: 'solid',
        color: '#e37151'
      },
      textColor: '#e8e8e8'
    },
  ],
  commands: [
    {
      type: 'search',
      trigger: '?'
    },
    {
      type: 'go',
      trigger: '/'
    }
  ],
  engines: {
    duckDuckGo: {
      name: 'DuckDuckGo',
      bgColor: {
        type: 'solid',
        color: '#e37151'
      },
      textColor: '#e8e8e8',
      types: {
        query: {
          template: 'https://duckduckgo.com/?q={$}'
        },
        calculator: {
          template: 'https://duckduckgo.com/?q={@}'
        },
        currency: {
          template: 'https://duckduckgo.com/?q={@}'
        }
      }
    },
  }
}

export default CONFIG

