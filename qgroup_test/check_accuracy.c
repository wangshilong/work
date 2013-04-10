#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
	if (argc < 4) {
		fprintf(stdout, "Usage: limited_size, data_size, accuracy\n");
		exit(EXIT_FAILURE);
	}
	
	puts(argv[1]);
	char *ptr;
	unsigned long long limit = strtoll(argv[1], &ptr, 10);
	if (ptr != argv[1]+strlen(argv[1])) {
		printf("invalid limit size\n");
		exit(EXIT_FAILURE);
	}

	unsigned long long data_size = strtoll(argv[2], &ptr, 10);
	if (ptr != argv[2]+strlen(argv[2])) {
		printf("invalid data_size\n");
		exit(EXIT_FAILURE);
	}

	unsigned long accuracy = strtol(argv[3], &ptr, 10);
	if (ptr != argv[3]+strlen(argv[3]) || accuracy > 100) {
		printf("invalid accuracy");
		exit(EXIT_FAILURE);
	}

	if (limit < data_size) {
		printf("data_size should not be more than limit\n");
		exit(EXIT_FAILURE);
	}

	double per = 100 * (double)data_size / limit;
	if (per < accuracy) {
		printf("out of accuracy\n");
		exit(EXIT_FAILURE);
	}
	exit(EXIT_SUCCESS);
}
