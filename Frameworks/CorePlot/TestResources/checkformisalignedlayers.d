#pragma D option quiet

CorePlot$target:::layer_position_change
{
	printf("Misaligned layer: %20s (%u.%03u, %u.%03u, %u.%03u, %u.%03u)\n", copyinstr(arg0), arg1 / 1000, arg1 % 1000, arg2 / 1000, arg2 % 1000, arg3 / 1000, arg3 % 1000, arg4 / 1000, arg4 % 1000 );
}