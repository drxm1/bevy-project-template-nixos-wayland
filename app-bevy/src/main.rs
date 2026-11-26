use std::time::Duration;

use bevy::{prelude::*, time::common_conditions::on_timer};
use lib_utils::UtilsPlugin;

fn main() {
    App::new()
        .add_plugins((DefaultPlugins, HelloPlugin, UtilsPlugin))
        .run();
}

struct HelloPlugin;

impl Plugin for HelloPlugin {
    fn build(&self, app: &mut App) {
        // The rename needs the entities queued by spawn_people.
        app.add_systems(Startup, (spawn_people, rename_person).chain())
            .add_systems(
                Update,
                greet_people.run_if(on_timer(Duration::from_secs(2))),
            );
    }
}

#[derive(Component)]
struct Person;

fn spawn_people(mut commands: Commands) {
    let names = ["Elaina Proctor", "Renzo Hume", "Zayna Nieves"];
    commands.spawn_batch(names.map(|name| (Person, Name::new(name))));
}

fn rename_person(mut people: Query<&mut Name, With<Person>>) {
    for mut name in &mut people {
        if name.as_str() == "Elaina Proctor" {
            name.set("Elaina Hume");
            break;
        }
    }
}

fn greet_people(people: Query<&Name, With<Person>>) {
    for name in &people {
        info!("hello {name}!");
    }
}
