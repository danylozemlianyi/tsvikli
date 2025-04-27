import yaml
import pymysql
import hashlib
import boto3
import os


def get_db_credentials(secret_name):
    session = boto3.session.Session()
    client = session.client(service_name="secretsmanager")
    secret_response = client.get_secret_value(SecretId=secret_name)
    return yaml.safe_load(secret_response["SecretString"])


def hash_password(password, salt):
    salted_password = salt + password
    return hashlib.sha256(salted_password.encode("utf-8")).hexdigest()


def generate_salt():
    return os.urandom(32).hex()


def connect_db(credentials):
    return pymysql.connect(
        host=credentials["host"],
        user=credentials["username"],
        password=credentials["password"],
        database=credentials["dbname"],
        port=credentials.get("port", 3306),
        connect_timeout=10,
        read_timeout=30,
        write_timeout=30,
        cursorclass=pymysql.cursors.DictCursor,
        charset="utf8mb4",
        autocommit=True,
    )


def reset_guacamole_tables(cursor):
    tables_to_clear = [
        "guacamole_connection_permission",
        "guacamole_user_permission",
        "guacamole_system_permission",
        "guacamole_connection_parameter",
        "guacamole_connection",
        "guacamole_user",
        "guacamole_entity",
    ]
    for table in tables_to_clear:
        cursor.execute(f"DELETE FROM {table}")


def create_user(cursor, username, password):
    cursor.execute(
        """
        INSERT INTO guacamole_entity (name, type)
        VALUES (%s, 'USER')
        """,
        (username,),
    )
    entity_id = cursor.lastrowid

    salt = generate_salt()
    password_hash = hash_password(password, salt)
    cursor.execute(
        """
        INSERT INTO guacamole_user (entity_id, password_hash, password_salt, password_date, disabled)
        VALUES (%s, %s, %s, NOW(), 0)
        """,
        (entity_id, password_hash, salt),
    )

    return entity_id


def create_connection(cursor, machine):
    cursor.execute(
        """
        INSERT INTO guacamole_connection (connection_name, protocol)
        VALUES (%s, %s)
        """,
        (machine["id"], machine["protocol"]),
    )
    connection_id = cursor.lastrowid

    connection_params = {
        "hostname": machine["hostname"],
        "port": str(machine["port"]),
        "username": machine["username"],
        "password": machine.get("password"),
        "private-key": machine.get("private_key"),
    }

    for param_name, param_value in connection_params.items():
        if param_value:
            cursor.execute(
                """
                INSERT INTO guacamole_connection_parameter (connection_id, parameter_name, parameter_value)
                VALUES (%s, %s, %s)
                """,
                (connection_id, param_name, param_value),
            )

    return connection_id


def grant_connection_permission(cursor, user_entity_id, connection_id):
    cursor.execute(
        """
        INSERT INTO guacamole_connection_permission (entity_id, connection_id, permission)
        VALUES (%s, %s, 'READ')
        """,
        (user_entity_id, connection_id),
    )


def grant_system_permission(cursor, user_entity_id):
    permissions = ["CREATE_CONNECTION", "CREATE_CONNECTION_GROUP", "CREATE_USER", "ADMINISTER"]
    for permission in permissions:
        cursor.execute(
            """
            INSERT INTO guacamole_system_permission (entity_id, permission)
            VALUES (%s, %s)
            """,
            (user_entity_id, permission),
        )


def lambda_handler(event, context):
    secret_name = os.environ["DB_SECRET_NAME"]
    yaml_s3_bucket = os.environ["CONFIG_BUCKET"]
    yaml_s3_key = os.environ["CONFIG_KEY"]

    s3 = boto3.client("s3")
    yaml_content = s3.get_object(Bucket=yaml_s3_bucket, Key=yaml_s3_key)["Body"].read()
    config = yaml.safe_load(yaml_content)

    credentials = get_db_credentials(secret_name)
    connection = connect_db(credentials)

    try:
        with connection.cursor() as cursor:
            reset_guacamole_tables(cursor)

            user_entity_ids = {}
            for user in config["users"]:
                entity_id = create_user(cursor, user["username"], user["password"])
                user_entity_ids[user["username"]] = entity_id

            connection_ids = {}
            for machine in config["machines"]:
                conn_id = create_connection(cursor, machine)
                connection_ids[machine["id"]] = conn_id

            for user in config["users"]:
                for machine_id in user.get("connections", []):
                    grant_connection_permission(
                        cursor, user_entity_ids[user["username"]], connection_ids[machine_id]
                    )

    finally:
        connection.close()

    return {"statusCode": 200, "body": "Guacamole database updated successfully"}
