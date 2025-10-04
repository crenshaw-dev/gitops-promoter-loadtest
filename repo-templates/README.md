# Default Repository Templates

This directory contains the default templates for asset repositories (config and deployment repos). These templates provide a basic, open-source-friendly structure that works for general use.

## Structure

```
repo-templates/
├── asset-config/       # Config repository templates (optional)
│   └── README.md.tpl   # Simple README with variable documentation
└── asset-deployment/   # Deployment repository templates
    └── configmap.yaml.tpl  # Simple Kubernetes ConfigMap
```

## Customization

To customize templates for your organization:

1. Create `repo-templates.local/` directory (gitignored by default)
2. Copy templates to `repo-templates.local/asset-config/` or `repo-templates.local/asset-deployment/`
3. Modify as needed - the script will use local templates if they exist

Example organization-specific templates can be added to `repo-templates.local/` (this directory is gitignored).

## Template Variables

See `repo-templates.local/README.md` for a complete list of available template variables.

## Disabling Config Repositories

For open-source usage where only deployment repos are needed, set in `config.local.sh`:

```bash
export CREATE_CONFIG_REPO=false
```

This will skip creating config repositories entirely.

