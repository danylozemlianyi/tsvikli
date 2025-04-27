import json
import boto3
import pymysql
import os


def get_db_credentials(secret_name):
    session = boto3.session.Session()
    client = session.client(service_name="secretsmanager")
    secret_response = client.get_secret_value(SecretId=secret_name)
    return json.loads(secret_response["SecretString"])


def lambda_handler(event, context):
    secret_name = os.environ["DB_SECRET_NAME"]
    sql_file_path = "/var/task/001-create-schema.sql"

    try:
        creds = get_db_credentials(secret_name)
        db_host = creds["host"]
        db_user = creds["username"]
        db_password = creds["password"]
        db_name = creds["dbname"]
        db_port = creds.get("port", 3306)

        connection = pymysql.connect(
            host=db_host,
            user=db_user,
            password=db_password,
            database=db_name,
            port=db_port,
            connect_timeout=10,
            read_timeout=30,
            write_timeout=30,
            cursorclass=pymysql.cursors.DictCursor,
            charset="utf8mb4",
            autocommit=True,
        )

        with connection.cursor() as cursor:
            with open(sql_file_path, "r") as f:
                lines = f.readlines()

            sql_lines = []
            for line in lines:
                stripped_line = line.strip()
                if not stripped_line or stripped_line.startswith("--"):
                    continue
                sql_lines.append(stripped_line)

            sql_content = " ".join(sql_lines)
            statements = [stmt.strip() for stmt in sql_content.split(";") if stmt.strip()]

            for statement in statements:
                try:
                    cursor.execute(statement)
                except pymysql.MySQLError as e:
                    raise (e)
            
            try:
                cursor.execute(f"""
                    CREATE USER IF NOT EXISTS 'guacamole_user'@'%' IDENTIFIED BY '{db_password}';
                """)
                cursor.execute(f"""
                    GRANT SELECT, INSERT, UPDATE, DELETE ON {db_name}.* TO 'guacamole_user'@'%';
                """)
                cursor.execute("FLUSH PRIVILEGES;")
            except pymysql.MySQLError as e:
                raise (e)

    except Exception as e:
        raise (e)

    finally:
        try:
            if connection:
                connection.close()
        except Exception as e:
            print(e)

    return {"statusCode": 200, "body": json.dumps("Database initialized successfully")}
