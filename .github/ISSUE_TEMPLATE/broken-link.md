name: 链接失效报告
about: 报告清单里打不开 / 404 的下载链接
title: '[死链] '
labels: ['broken-link']
body:
  - type: input
    id: app
    attributes:
      label: 哪个软件
      placeholder: 例如：CC Switch / Ollama
    validations:
      required: true
  - type: input
    id: link
    attributes:
      label: 失效的链接（从清单页复制）
      placeholder: https://...
    validations:
      required: true
  - type: dropdown
    id: where
    attributes:
      label: 在哪里遇到的
      options:
        - 在线清单页（GitHub Pages）
        - 下载的离线清单 html
        - 双击启动.bat（命令行启动器）
        - 打开资源中心.bat（图形界面）
        - 其他
  - type: textarea
    id: detail
    attributes:
      label: 补充信息（报错内容 / 时间 / 是否有代理）
      placeholder: 可留空
