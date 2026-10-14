insert into cs_universities (name, short_name, city, state) values
 ('Ekiti State University', 'EKSU', 'Ado-Ekiti', 'Ekiti'),
 ('Federal University Oye-Ekiti', 'FUOYE', 'Oye-Ekiti', 'Ekiti')
on conflict (name) do nothing;
