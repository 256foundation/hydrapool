// Copyright (C) 2024-2026 Hydrapool Developers (see AUTHORS)
//
// This file is part of Hydrapool.
//
// Hydrapool is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.
//
// Hydrapool is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with
// Hydrapool. If not, see <https://www.gnu.org/licenses/>.

use p2poolv2_cli::commands;
use std::error::Error;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    commands::run().await
}
