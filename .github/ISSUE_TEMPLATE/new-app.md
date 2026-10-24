name: 申请收录新软件
about: 推荐一款值得进清单的 AI 客户端 / Agent / CLI 工具
title: '[收录申请] '
labels: ['new-app']
body:
  - type: input
    id: name
    attributes:
      label: 软件名称
    validations:
      required: true
  - type: input
    id: page
    attributes:
      label: 官方主页 / 下载页
      placeholder: https://...
    validations:
      required: true
  - type: dropdown
    id: kind
    attributes:
      label: 类型
      options:
        - 桌面客户端
        - Agent 工作台
        - IDE / 编辑器
        - 命令行工具（CLI）
        - 本地模型运行
        - 实用工具
        - 其他
  - type: textarea
    id: why
    attributes:
      label: 一句话：它解决什么问题，为什么值得收
      placeholder: 收录标准：有官方直链或官方安装方式、对国内用户可达成（直连或镜像）、不重复收录同类
    validations:
      required: true
  - type: checkboxes
    id: checks
    attributes:
      label: 确认
      options:
        - label: 我确认这是官方页面，不是二次打包 / 修改版
          required: true
