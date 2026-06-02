import time
import psycopg2

from psycopg2.extensions import connection as PgConnection

from injector_app.domain.measurement import Measurement
from injector_app.infrastructure.config import DbConfig

def get_db_connection(db_config: DbConfig) -> PgConnection:
    while True:
        try:
            connection = psycopg2.connect(
                host=db_config.host,
                port=db_config.port,
                dbname=db_config.dbname,
                user=db_config.user,
                password=db_config.password,
            )
            connection.autocommit = False
            print("Conectado a PostgreSQL")
            return connection
        except Exception as e:
            print(f"Error conectando a PostgreSQL: {e}")
            time.sleep(5)

def insert_measurements(db_connection: PgConnection, measurements: list[Measurement]) -> None:
    # No se captura la excepción aquí porque esta función forma parte de un flujo transaccional.
    # Si falla la inserción, el error debe propagarse hasta el bucle principal para hacer rollback
    # y evitar eliminar el mensaje de la cola de procesamiento de Redis. Así no se pierden datos:
    # el mensaje queda pendiente y podrá reintentarse cuando se corrija el problema.
    query = """
        INSERT INTO measurements (
            created_at,
            variable_id,
            value
        )
        SELECT
            %s,
            id,
            %s
        FROM measurement_variables
        WHERE original_name = %s
        AND active = TRUE
    """

    with db_connection.cursor() as cursor:
        for measurement in measurements:
            cursor.execute(
                query,
                (
                    measurement.published_at,
                    measurement.value,
                    measurement.internal_name
                ),
            )

    db_connection.commit()


   