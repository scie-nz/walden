import os
from celery.schedules import crontab
from cachelib.redis import RedisCache

def env(key, default=None):
    val = os.getenv(key, default)
    if val is None:
        raise Exception("Missing required envvar: {}".format(key))
    return val

MAPBOX_API_KEY = env('MAPBOX_API_KEY', '')
CACHE_CONFIG = {
    'CACHE_TYPE': 'redis',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_HOST': env('REDIS_HOST'),
    'CACHE_REDIS_PORT': env('REDIS_PORT', 6379),
    'CACHE_REDIS_PASSWORD': env('REDIS_PASSWORD'),
    'CACHE_REDIS_DB': env('REDIS_CACHE_DB', 1),
}
DATA_CACHE_CONFIG = CACHE_CONFIG
EXPLORE_FORM_DATA_CACHE_CONFIG = CACHE_CONFIG
FILTER_STATE_CACHE_CONFIG = CACHE_CONFIG

SQLALCHEMY_DATABASE_URI = f"postgresql+psycopg2://{env('POSTGRES_USER')}:{env('POSTGRES_PASSWORD')}@{env('POSTGRES_HOST')}:{env('POSTGRES_PORT', 5432)}/{env('POSTGRES_DB', 'superset')}"
SQLALCHEMY_TRACK_MODIFICATIONS = True
SECRET_KEY = env('SECRET_KEY')

# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = True
# Add endpoints that need to be exempt from CSRF protection
WTF_CSRF_EXEMPT_LIST = []
# A CSRF token that expires in 1 year
WTF_CSRF_TIME_LIMIT = 60 * 60 * 24 * 365

class CeleryConfig(object):
    BROKER_URL = f"redis://:{env('REDIS_PASSWORD')}@{env('REDIS_HOST')}:{env('REDIS_PORT', 6379)}/{env('REDIS_CELERY_DB', 0)}"
    CELERY_IMPORTS = ('superset.sql_lab', )
    CELERY_RESULT_BACKEND = f"redis://:{env('REDIS_PASSWORD')}@{env('REDIS_HOST')}:{env('REDIS_PORT', 6379)}/{env('REDIS_RESULTS_DB', 1)}"
    CELERYD_LOG_LEVEL = "DEBUG"
    CELERYD_PREFETCH_MULTIPLIER = 1
    CELERY_ACKS_LATE = True
    CELERY_ANNOTATIONS = {
        'tasks.add': {
            'rate_limit': '10/s'
        },
        'sql_lab.get_sql_results': {
            'rate_limit': '100/s',
        },
        'email_reports.send': {
            'rate_limit': '1/s',
            'time_limit': 600,
            'soft_time_limit': 600,
            'ignore_result': True,
        }
    }
    CELERYBEAT_SCHEDULE = {
        'reports.scheduler': {
            'task': 'reports.scheduler',
            'schedule': crontab(minute='*', hour='*'),
        },
        'reports.prune_log': {
            'task': 'reports.prune_log',
            'schedule': crontab(minute=0, hour=0),
        }
    }
CELERY_CONFIG = CeleryConfig

RESULTS_BACKEND = RedisCache(
    host=env('REDIS_HOST'),
    port=env('REDIS_PORT', 6379),
    password=env('REDIS_PASSWORD'),
    db=env('REDIS_CELERY_DB', 0),
    key_prefix='superset_results'
)

####
# User superset_config.py (from 'superset-custom' ConfigMap) begins here
####
