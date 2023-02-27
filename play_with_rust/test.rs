use std::io;

fn disemvowel(s: &str) -> String {
    let vowels = ['a', 'e', 'i', 'o', 'u', 'A', 'E', 'I', 'O', 'U'];
    s.chars()
        .filter(|&c| !vowels.contains(&c))
        .collect()
}

fn main() {
    let mut input = String::new();
    io::stdin().read_line(&mut input).expect("Failed to read line");
    let disemvoweled = disemvowel(&input);
    println!("{}", disemvoweled);
}

