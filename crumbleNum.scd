(
~crumbleNum = { arg num = 16, crumbles = [0.25, 0.5, 0.75, 1];
	var
	result = [],
	localNum = num,
	orderedCrumbles = Array.newFrom(crumbles).sort,
	minCrumble = orderedCrumbles[0],
	maxCrumble = orderedCrumbles[orderedCrumbles.size - 1],
	newCrumble,
	validationArr = Array.newFrom(orderedCrumbles)++num;

	validationArr.do({ |num|
		var mult = num/minCrumble;
		if (mult - mult.floor != 0,
			{
				Error(
					"the given number and its crumbles\n"
					"must all be whole-number multiples\n"
					"of the smallest crumble";
				).throw
			}
		)
	});

	while (
		{ localNum > maxCrumble },
		{
			newCrumble = crumbles.choose;
			result = result++newCrumble;
			localNum = localNum - newCrumble;
		}
	);

	if (orderedCrumbles.find([localNum]) !== nil or: {minCrumble >= localNum},
		{ result = result++localNum },
		{ result = result++~crumbleNum.value(
			localNum,
			orderedCrumbles.removeAllSuchThat({ |i| i <= localNum }))
		}
	);
	result;
};
)