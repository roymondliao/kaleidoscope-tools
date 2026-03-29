# Project Conversation Guidelines
1. Use `uv` to manage python dependencies and `pyproject.toml` for dependency management.
2. Use `pytest` for unit testing.
3. Use `source .venv/bin/activate` to activate the virtual environment.
4. Use `terraform` for infrastructure as code and follow below commands to check syntax:
   - `terraform fmt -check -recursive`
   - `terraform validate`
   - `terraform plan --var-file="<var_file>" -out="tfplan.binary"`
   - `terraform apply "tfplan.binary"`
