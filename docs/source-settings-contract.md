# Source settings form contract

The parent renders source settings from authenticated `GET /v1/descriptor?sourceKey=...`.
It checks protocol/source identity, `temporal:true`, and
`capabilities.validateSettings:true`. The live schema is authoritative for the
form; stored registry schema snapshots are not used for editing.

## Supported JSON Schema subset

The root is `{type:"object",properties:{...},additionalProperties:false}`.
An optional `required` array names declared properties. Each property has a
`title`, optional `description`, and one of these shapes:

- Boolean: `{type:"boolean",title:"Show alerts",default:false}`.
- Multiple choices: `{type:"array",title:"Locations",default:[],uniqueItems:true,
  items:{type:"string",oneOf:[{const:"west",title:"West","x-group":"Regions"}]}}`.

`x-group` is the only UI extension. Choice values are stable strings;
titles and optional groups are display text. Declaration order determines form
order. Defaults apply when displaying a field with no saved value. Empty
`properties` means no settings. Field names start with a letter and contain
only letters, digits, and underscores; prototype-related names are rejected.

Unsupported property types or constraints fail closed, with no save form.
This is deliberately not a general JSON Schema renderer. No nested objects,
free text, numbers, conditional fields, pagination, or source-supplied HTML/JS.
All labels are escaped by React. Legacy descriptor `options` is not consumed:
the choice-to-property binding is inside `settingsSchema`.

A source may provide a static schema or an async `settingsSchema()` function.
Sports builds choices from its catalog in one descriptor request. Moon publishes
the empty object schema. No source data tables need changing.

## Saving

The form includes a fingerprint of the rendered fields. The parent reloads the
descriptor on POST and rejects a changed fingerprint with 409; it does not
silently interpret an old form against new controls or choices.

The parent decodes only declared fields. Unchecked booleans become false and
unselected arrays become []; defaults do not override an intentional clearing.
Unknown fields, duplicate values, and unavailable choices are rejected.
Previously saved choices that disappear remain visible as checked unavailable
values, requiring explicit removal.

Before persisting, the parent sends
`POST /v1/validate-settings` with
`{protocolVersion:1,sourceKey,settings}`.
The SDK invokes the same `parseSettings` used by reads and returns only
`{protocolVersion:1,sourceKey,ok:true}`. It does not call `read`, perform writes,
or expose parsed internal context. Implementers must keep `parseSettings`
free of mutation. Validation remains source-authoritative on every feed read,
since data/choices may change after a settings save.

Source validation errors retain their stable error code. Unavailability returns
502, invalid settings 422, and stale forms 409. None changes the assignment.
Successful saves persist the original wire settings, then use the existing
device notification path.

## Scope and remaining coupling

Device settings routes and rendering have no source-kind dispatch, field-name
knowledge, or sports catalog import. Another source supporting this profile
needs only a registered pointer and its descriptor/validation/read implementation.

Prototype starter-feed defaults and operator ingestion/catalog/coverage adapters
still refer to Sports/Moon instance IDs. Removing those is separate from settings
forms. Immutable releases, descriptor caching, schema migrations, and agent ACLs
remain deferred.

