import {
  List,
  Datagrid,
  TextField,
  DateField,
  Edit,
  SimpleForm,
  TextInput,
  NumberInput,
  SelectInput,
  Create,
  Show,
  SimpleShowLayout,
  FilterButton,
  TopToolbar,
  CreateButton,
  ExportButton,
} from 'react-admin';

// System settings list actions
const SettingsListActions = () => (
  <TopToolbar>
    <FilterButton />
    <CreateButton />
    <ExportButton />
  </TopToolbar>
);

// System settings list
export const SystemSettingsList = () => (
  <List actions={<SettingsListActions />} filters={settingsFilters}>
    <Datagrid rowClick="edit">
      <TextField source="id" label="ID" />
      <TextField source="type" label="Type" />
      <TextField source="name" label="Setting Name" />
      <TextField source="value" label="Setting Value" />
      <TextField source="sort" label="Sort" />
      <TextField source="remark" label="Remark" />
      <DateField source="created_at" label="Created At" showTime />
      <DateField source="updated_at" label="Updated At" showTime />
    </Datagrid>
  </List>
);

// Filters
const settingsFilters = [
  <TextInput label="Type" source="type" alwaysOn />,
  <TextInput label="Name" source="name" />,
];

// System setting edit
export const SystemSettingsEdit = () => (
  <Edit>
    <SimpleForm>
      <TextInput source="id" disabled />
      <SelectInput
        source="type"
        label="Type"
        required
        choices={[
          { id: 'system', name: 'System Settings' },
          { id: 'radius', name: 'RADIUS Settings' },
          { id: 'security', name: 'Security Settings' },
          { id: 'network', name: 'Network Settings' },
          { id: 'email', name: 'Email Settings' },
          { id: 'other', name: 'Other Settings' },
        ]}
      />
      <TextInput source="name" label="Setting Name" required />
      <TextInput source="value" label="Setting Value" required multiline rows={3} />
      <NumberInput source="sort" label="Sort" defaultValue={0} />
      <TextInput source="remark" label="Remark" multiline rows={2} />
    </SimpleForm>
  </Edit>
);

// System setting create
export const SystemSettingsCreate = () => (
  <Create>
    <SimpleForm>
      <SelectInput
        source="type"
        label="Type"
        required
        defaultValue="system"
        choices={[
          { id: 'system', name: 'System Settings' },
          { id: 'radius', name: 'RADIUS Settings' },
          { id: 'security', name: 'Security Settings' },
          { id: 'network', name: 'Network Settings' },
          { id: 'email', name: 'Email Settings' },
          { id: 'other', name: 'Other Settings' },
        ]}
      />
      <TextInput source="name" label="Setting Name" required />
      <TextInput source="value" label="Setting Value" required multiline rows={3} />
      <NumberInput source="sort" label="Sort" defaultValue={0} />
      <TextInput source="remark" label="Remark" multiline rows={2} />
    </SimpleForm>
  </Create>
);

// System setting details
export const SystemSettingsShow = () => (
  <Show>
    <SimpleShowLayout>
      <TextField source="id" label="ID" />
      <TextField source="type" label="Type" />
      <TextField source="name" label="Setting Name" />
      <TextField source="value" label="Setting Value" />
      <TextField source="sort" label="Sort" />
      <TextField source="remark" label="Remark" />
      <DateField source="created_at" label="Created At" showTime />
      <DateField source="updated_at" label="Updated At" showTime />
    </SimpleShowLayout>
  </Show>
);
