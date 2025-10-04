apiVersion: v1
kind: Namespace
metadata:
  name: promoter-test-{{ASSET_ID}}-{{ENV}}-{{REGION}}
  labels:
    load-test: "true"
    load-test-run: "{{TIMESTAMP}}"
    asset-id: "{{ASSET_ID}}"
    environment: "{{ENV}}"
    region: "{{REGION}}"

