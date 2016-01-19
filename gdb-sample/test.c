/* Copy from:
 * http://www.c4learn.com/c-programs/c-program-to-implement-stack-operations-using-array.html
 */
#include <stdio.h>
#include <stdlib.h>

#define size 5
struct stack {
	int s[size];
	int top;
} st;

int stfull()
{
	if (st.top >= size - 1)
		return 1;
	else
		return 0;
}

void push(int item)
{
	st.top++;
	st.s[st.top] = item;
}

int stempty()
{
	if (st.top == -1)
		return 1;
	else
		return 0;
}

int pop()
{
	int item;
	item = st.s[st.top];
	st.top--;
	return (item);
}

void display()
{
	int i;
	if (stempty())
		printf("\nStack Is Empty!");
	else {
		for (i = st.top; i >= 0; i--)
			printf("\n%d", st.s[i]);
	}
}

int main()
{
	int item;
	int i;
	int data[] = {1,2,3,4,5,6,7,8,9};

	st.top = -1;

	for (i = 0; i < sizeof(data)/sizeof(data[0]); i++) {
		if (stfull()) {
			printf("\nStack is Full, push fail: %d", data[i]);
			break;
		}
		else
			push(data[i]);
	}

	display();

	while (!stempty()) {
		item = pop();
		printf("\nThe popped element is %d", item);
	}

	return 0;
}
