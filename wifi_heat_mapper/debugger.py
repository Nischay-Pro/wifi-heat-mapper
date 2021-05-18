from functools import wraps
import logging


def log_arguments(func):

    @wraps(func)
    def new_func(*args, **kwargs):
        args_passed = locals()
        logging.debug("Calling {0}".format(func.__name__))
        logging.debug("Arguments: {0}".format(args_passed))
        return func(*args, **kwargs)
    return new_func
