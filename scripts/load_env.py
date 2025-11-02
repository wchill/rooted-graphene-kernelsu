import json
import sys


def main(filename):
    with open(filename, "r") as f:
        env = json.load(f)
        for key, value in env.items():
            print(f"{key}={value}")


if __name__ == "__main__":
    main(sys.argv[1])
