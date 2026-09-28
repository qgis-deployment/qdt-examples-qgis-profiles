# QGIS User Conference 2026 Profile

A QGIS profile built around the QGIS User Conference 2026 in Laax, Switzerland, bundling the plugins presented during the conference and Swiss base data ready to use.

## Content

- Plugins presented at the conference:
  - QFieldSync
  - Mergin Maps
  - Lizmap
  - QGIS Model Baker
  - NextGIS Connect
  - oQtopus
  - brdrQ
  - QBeach
  - qfit
- Swiss Locator: a QGIS plugin that adds Swiss address search directly to the locator bar
- swisstopo vector tiles basemap and swisstopo WMS service preconfigured
- Default project centred on the conference venue in Laax

## Deployment rules

QDT deploys this profile if at least one of the following conditions is met:

- The current date is between September 2026 and September 2027 (inclusive)
- The `QDT_LAAX_ATTENDEE` environment variable is set to `true`

## Screenshot

![QGIS User Conference 2026 profile preview](https://github.com/qgis-deployment/qdt-examples-qgis-profiles/blob/main/fixtures/img/qgis_user_conference_2026_preview.png?raw=true)
